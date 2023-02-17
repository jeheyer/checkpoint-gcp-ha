#!/bin/env python3

#   Copyright 2018 Check Point Software Technologies LTD
#
#   Modified December 2022 jheyer@opentext.com
#

import datetime
import errno
import json
import logging
import logging.handlers
import os
import re
import select
import socket
import subprocess
import time
import traceback

from platform import node

import gcp as _gcp

HIGH_PRIORITY = 1
LOW_PRIORITY = 2
HOSTNAME = node()
CHKP_TAG = HOSTNAME[0:-8]   # strip off the "member-[a|b]" portion of the hostname
TO_MEMBER_A = '-a'
TO_MEMBER_B = '-b'
MAX_VPC_NAME_LENGTH = 38

os.environ['GCP_NO_DOT'] = 'true'
logFilename = os.environ['FWDIR'] + '/log/gcp_had.elg'

logger = logging.getLogger('GCP-CP-HA')

api = None
conf = {}

pending_routes_requests = []
pending_address_requests = []


# ENUMs for cluster members config
class MEMBER(set):
    MEMBER_A_SUFFIX = 'member-a'
    NAME = 'name'


def gcp(method, path, query=None, body=None, aggregate=False):
    try:
        head, res = api.rest(method, path, query=query, body=body,
                             aggregate=aggregate)

        if not res:
            # TODO: Instead of ValueError exception, create another
            #  one in the cme_exceptions when it becomes production
            raise ValueError("Result is empty")

        return res

    except _gcp.HTTPException as e:
        if e.body and 'error' in e.body:
            error = json.loads(e.body)['error']
            logger.error('HTTP error {}: {} failed for {}. {}'.format(
                error.get('code', 'unknown'), method, path,
                error.get('message', 'unknown reason')))
        else:
            logger.error('Failed to parse error: {}'.format(e))
        logger.debug('%s', traceback.format_exc())
    except Exception as e:
        logger.debug('GCP API call failed: {}'.format(e))
        logger.debug('%s', traceback.format_exc())


def string_to_date(date):
    date_format = '%Y-%m-%dT%H:%M:%S.%f'
    return datetime.datetime.strptime(date[:-6], date_format)


def is_req_done(req):
    res = gcp('GET', req)

    if not res or res.get('status') in ('PENDING', 'RUNNING'):
        return False

    if res.get('error'):
        logger.error('Operation {operationType} for {targetLink} '
                     'error {error}'.format(**res))
    elif res.get('warnings'):
        logger.warning('Operation {operationType} for {targetLink} '
                       'warning {warnings}'.format(**res))
    else:
        start_time = string_to_date(res['insertTime'])
        end_time = string_to_date(res['endTime'])
        logger.info(
            'Operation {operationType} for {targetLink} '
            '{status}'.format(**res) + ' in {} seconds '
                                       '({})'.format(
                (end_time - start_time).total_seconds(), req))
    return True


def add_external_ip_to_instance(instance, access_config_name, address,
                                nic='nic0'):
    if address['status'] == 'IN_USE':
        logger.error('Address {name} (IP {address}) is in use, '
                     'can\'t attach it'.format(**address))
        return

    logger.info('Attaching external IP address {} (IP {}) to'
                ' {}'.format(address['name'], address['address'],
                             instance))
    query = {
        'networkInterface': nic
    }

    access_config = {
        'name': access_config_name,
        'natIP': address['address']
    }

    return gcp('POST', instance + '/addAccessConfig', query=query,
               body=json.dumps(access_config))['selfLink']


def remove_external_ip_from_instance(address, access_config_name,
                                     nic='nic0'):
    if address['status'] != 'IN_USE':
        logger.error('Address {name} (IP {address}) not in use, '
                     'can\'t detach it'.format(**address))
        return

    used_by = address['users'][0]
    logger.debug('Detaching address {} (IP {}) '
                 'from {}'.format(address['name'],
                                  address['address'], used_by))
    query = {
        'accessConfig': access_config_name,
        'networkInterface': nic
    }

    return gcp('POST', used_by + '/deleteAccessConfig',
               query=query)['selfLink']


def get_address(name, project=None, region=None):
    if not project:
        project = conf['project']

    if not region:
        region = conf['region']

    return gcp('GET', '/projects/{}/regions/{}/'
                      'addresses/{}'.format(project, region, name))


def create_route_request(name, network, range, priority, next_hop_instance,
                         project, tags = []):
    logger.info('Adding route "' + name + '":' +
                '\n\t network: ' + network +
                '\n\t range: ' + range +
                '\n\t priority: ' + str(priority) +
                '\n\t tags: ' + str(tags) +
                '\n\t next hop instance: ' + next_hop_instance)
    path = '/projects/{}/global/routes'.format(project)

    route = {
        'destRange': range,
        'name': name,
        'network': '/projects/{}/global/networks/{}'.format(project, network),
        'priority': priority,
        'tags': tags,
        'nextHopInstance': next_hop_instance
    }
    return gcp('POST', path, body=json.dumps(route))['selfLink']


def add_route(name, network, priority, next_hop_instance, routes,
              range=None, project=None):
    pending_routes_requests = []

    if not project:
        project = conf['project']

    # Get route tags from gcp-ha.json "route_tags" parameter
    ROUTE_TAGS = conf.get('route_tags', [])

    if not range:
        existing_routes_names = []
        for route in routes:
            existing_routes_names.append(route['name'])

        for count, dest_range in enumerate(conf['dest_ranges']):
            # Route name example : x-chkp-int-network1-a-0-0-0-0-0
            route_name = name + '-' + dest_range.replace('.', '-').replace('/',
                                                                           '-')
            if route_name not in existing_routes_names:
                route_req = create_route_request(route_name, network,
                                                 dest_range,
                                                 priority, next_hop_instance,
                                                 project, ROUTE_TAGS)
                pending_routes_requests.append(route_req)

    else:
        route_req = create_route_request(name, network, range, priority,
                                         next_hop_instance, project, ROUTE_TAGS)
        pending_routes_requests.append(route_req)

    return pending_routes_requests


def delete_route(name, project=None):
    if not project:
        project = conf['project']

    return gcp('DELETE',
               '/projects/{}/global/routes/{}'.format(project,
                                                      name))['selfLink']


def get_routes(networks=None, project=None):
    query = {}
    if networks:
        query['filter'] = 'network eq .*/(' + '|'.join(networks) + ')$'

    if not project:
        project = conf['project']

    path = '/projects/{}/global/routes'.format(project)

    return gcp('GET', path, query=query, aggregate=True)


def set_public_address():
    logger.debug('set_public_address called')

    for request in pending_address_requests:
        if is_req_done(request):
            pending_address_requests.remove(request)
        else:
            return True

    cluster_address = get_address(conf['public_ip'])
    secondary_cluster_address = get_address(conf['secondary_public_ip'])

    if cluster_address['status'] == 'IN_USE' and \
            cluster_address['users'][0].split('/')[-1] != conf['name']:
        logger.info('Cluster IP address in use, detaching')
        req_link = remove_external_ip_from_instance(
            cluster_address, conf['access_config_name'])
        pending_address_requests.append(req_link)
    if secondary_cluster_address['status'] == 'IN_USE' \
            and secondary_cluster_address['users'][0].split('/')[-1] \
            == conf['name']:
        logger.info(
            'Secondary external IP address is attached to '
            'local member, detaching')
        req_link = remove_external_ip_from_instance(
            secondary_cluster_address, conf['access_config_name'])
        pending_address_requests.append(req_link)

    if pending_address_requests:
        return True

    if cluster_address['status'] != 'IN_USE':
        logger.info('Attaching cluster IP address to the local member')
        req_link = add_external_ip_to_instance(
            conf['self_link'], conf['access_config_name'], cluster_address)
        logger.info("Сompleted")
        pending_address_requests.append(req_link)
        return True

    return False


def check_unnecessary_routes(routes):
    for route in routes:
        if (not route['destRange'] in conf['dest_ranges'] and
            route['priority'] in [HIGH_PRIORITY, LOW_PRIORITY]) or (
                (not TO_MEMBER_A + '-' in route['name'])
                and (not TO_MEMBER_B + '-' in route['name'])
                and (route['priority'] in [HIGH_PRIORITY, LOW_PRIORITY])):
            if route['id'] != '-1':
                logger.debug('Deleting route "' + route['name'])
                req_link = delete_route(route['name'])
                pending_routes_requests.append(req_link)
                route['id'] = '-1'


def verify_routes_in_network(routes, b_route_name, network):
    # Verify that:
    #  - there are no unnecessary routes
    #  - all the desired secondary routes exist

    # Need to modify check_unnecessary_routes so it's aware of CHKP_TAG
    #check_unnecessary_routes(routes)

    if not conf['is_member_a']:
        add_route(b_route_name, network, LOW_PRIORITY, conf['self_link'],
                  routes)


def set_routing_tables():
    logger.debug('set_routing_tables called')

    for request in pending_routes_requests:
        if is_req_done(request):
            pending_routes_requests.remove(request)
        else:
            return True

    routes = get_routes(networks=conf['networks'])
    for network in conf['networks'][2:]:
        a_route_name = CHKP_TAG + network[-MAX_VPC_NAME_LENGTH:] + TO_MEMBER_A
        b_route_name = CHKP_TAG + network[-MAX_VPC_NAME_LENGTH:] + TO_MEMBER_B
        is_route_exists = \
            any(a_route_name in route['name'] for route in routes)

        if conf['is_member_a']:
            logger.info('Adding route with higher priority to local '
                        'member in network {}'.format(network))
            req_link = add_route(a_route_name, network, HIGH_PRIORITY,
                                 conf['self_link'], routes)
            for req in req_link:
                pending_routes_requests.append(req)

        if not conf['is_member_a'] and is_route_exists:
            logger.info('deleting route with higher priority to peer '
                        'member in network {}'.format(network))
            for route in routes:
                if a_route_name in route['name']:
                    req_link = delete_route(route['name'])
                    pending_routes_requests.append(req_link)

        verify_routes_in_network(routes, b_route_name, network)

    if pending_routes_requests:
        return True

    return False


def set_secondary_public_address():
    logger.debug('set_secondary_public_address called')

    secondary_cluster_address = get_address(conf['secondary_public_ip'])

    if secondary_cluster_address['status'] != 'IN_USE':
        cluster_address = get_address(conf['public_ip'])
        if cluster_address['status'] == 'IN_USE' and \
                cluster_address['users'][0].split('/')[-1] == conf['name']:
            logger.error('The cluster IP address is attached to local '
                         'member, failed to attach secondary external IP '
                         'address')
        else:
            logger.info('Attaching secondary external IP address '
                        'to local member')
            add_external_ip_to_instance(
                conf['self_link'], conf['access_config_name'],
                secondary_cluster_address)
            logger.info("Completed")


def set_local_active():
    '''set_local_active is called when:

    1. Socket receives CHANGED
    2. Every timeout if no messages received by the socket
       (non-blocking socket)

    The set functions this function contains should be asynchronous
    (non-blocking) and return:
    False when nothing to do or when done,
    True when started doing something that takes a while or while
    action is in progress.
    '''

    logger.debug('set_local_active called')

    pending = False
    pending |= set_routing_tables()
    pending |= set_public_address()
    if conf.get('pending') and not pending:
        logger.info('Failover complete')
    conf['pending'] = pending


def poll():
    logger.debug('poll called')

    try:
        cphaprob = subprocess.check_output(['cphaprob', 'stat'])
        logger.debug('{}'.format(cphaprob))
        matchObj = re.match(
            r'^.*\(local\)\s*([0-9.]*)\s*[0-9.\%]*\s*([a-zA-Z]*).*$',
            cphaprob.decode('utf-8'), re.MULTILINE | re.DOTALL)
        state = 'Unknown'
        if matchObj:
            state = matchObj.group(2)
        logger.debug('%s', 'state: ' + state)
        if state.lower() in ['active', 'active attention']:
            logger.debug(state + ' mode detected')
            set_local_active()
        else:
            set_secondary_public_address()
    except Exception:
        logger.debug('%s', traceback.format_exc())


class Server(object):
    def __init__(self):
        tmpdir = os.environ['FWDIR'] + '/tmp'
        self.pidFileName = os.path.join(tmpdir, 'ha.pid')
        self._regPid()
        self.sockpath = os.path.join(tmpdir, 'ha.sock')
        self.timeout = 10.0
        try:
            os.remove(self.sockpath)
        except Exception:
            pass
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
        self.sock.setblocking(0)
        self.sock.bind(self.sockpath)

    def __enter__(self):
        return self

    def __exit__(self, type, value, traceback):
        self._delPid()
        try:
            self.sock.close()
        except Exception:
            pass
        try:
            os.remove(self.sockpath)
        except Exception:
            pass

    def _delPid(self):
        try:
            os.remove(self.pidFileName)
        except Exception:
            pass

    def _regPid(self):
        with open(self.pidFileName, 'w') as f:
            f.write(str(os.getpid()))

    def run(self):
        handlers = [('RECONF', reconf), ('CHANGED', poll)]
        while True:
            rl, wl, xl = select.select([self.sock], [], [], self.timeout)
            events = set()
            while True:
                try:
                    dgram = self.sock.recv(1024)
                    logger.debug('%s', 'received: ' + dgram.decode('utf-8'))
                    events.add(dgram)
                except socket.error as e:
                    if e.args[0] in [errno.EAGAIN, errno.EWOULDBLOCK]:
                        events.add('CHANGED')
                        break
                    raise
            for h in handlers:
                if h[0] in events:
                    h[1]()
            if 'STOP' in events:
                logger.info('Leaving...')
                break


def create_secondary_routes():
    routes = get_routes(networks=conf['networks'])
    for network in conf['networks'][2:]:
        route_name = CHKP_TAG + network[-MAX_VPC_NAME_LENGTH:] + TO_MEMBER_B
        existing_routes_ranges = []
        for route in routes:
            if route['priority'] == LOW_PRIORITY:
                existing_routes_ranges.append(route['destRange'])
        is_route_exists = any(
            route_name in route['name'] for route in routes) and all(
            dest_ranges in existing_routes_ranges for dest_ranges in
            conf['dest_ranges'])
        if not is_route_exists:
            logger.info('Adding route with lower priority to local '
                        'member in network {}'.format(network))
            add_route(route_name, network, LOW_PRIORITY, conf['self_link'],
                      routes)


def is_member_a():
    """
    In the cluster template each vm instance is appended with
    its  mode. Meaning first instance which is created ends
    with "member-a" and the second one with "member-b.
    Base on the the behavior described above the "is_member_a" function decides
    whether a vm instance is member a according to suffix name
    :return: boolean True if member is A else False
    """
    #if conf[MEMBER.NAME].endswith(MEMBER.MEMBER_A_SUFFIX):
    if HOSTNAME.endswith("-a") or HOSTNAME.endwith("-primary") or HOSTNAME.endwith("-1") or HOSTNAME.endswith("01"):
        logger.debug('Operating in member a mode')
        return True

    logger.debug('Operating in member b mode')
    return False


def reconf():
    logger.debug('reconf called')

    global conf
    with open(os.environ['FWDIR'] + '/conf/gcp-ha.json') as f:
        conf = json.load(f)

    if conf.get('debug'):
        logger.setLevel(logging.DEBUG)

    global api
    api = _gcp.GCP('IAM', max_time=500)

    metadata = api.metadata()[0]

    conf['project'] = metadata['project']['projectId']

    conf['networks'] = []
    for interface in metadata['instance']['networkInterfaces']:
        _, project, _, network = interface['network'].split('/')

        if project in {
            str(metadata['project']['numericProjectId']), metadata[
                'project']['projectId']}:
            conf['networks'].append(network)

    conf['name'] = metadata['instance']['name']
    conf['zone'] = metadata['instance']['zone'].split('/')[-1]
    conf['region'] = '-'.join(conf['zone'].split('-')[:2])
    conf['self_link'] = ('/projects/{project}/'
                         'zones/{zone}/instances/{name}'.format(**conf))
    conf['access_config_name'] = CHKP_TAG + 'access-config'
    conf['private_ip'] = metadata['instance']['networkInterfaces'][0]['ip']
    conf['is_member_a'] = is_member_a()

    if not conf['is_member_a']:
        create_secondary_routes()

    logger.info('Configuration is completed:\n {}'.format(conf))


def main():
    handler = logging.handlers.RotatingFileHandler(logFilename,
                                                   maxBytes=1000000,
                                                   backupCount=10)

    formatter = logging.Formatter(
        '%(asctime)s-%(name)s-%(levelname)s- %(message)s')
    handler.setFormatter(formatter)
    logger.addHandler(handler)

    logger.setLevel(logging.INFO)
    logger.info('Started')

    while True:
        try:
            reconf()
            break
        except Exception:
            logger.debug('%s', traceback.format_exc())
            time.sleep(5)

    with Server() as server:
        server.run()


if __name__ == '__main__':
    main()
