#!/usr/bin/python
#Cobbled together from yaml-to-json.py (git.linaro.org/ci/lci-build-tools) and
#post-build-lava.py (git.linaro.org/ci/post-build-lava.git).

import collections
import subprocess
import argparse
import itertools
import json
import os
import string
import sys
import yaml
import xmlrpclib
import keyring.core

args = {}

def dispatch(config):
  lava_server_root = args['lava_server'].rstrip('/')
  if lava_server_root.endswith('/RPC2'):
    lava_server_root = lava_server_root[:-len('/RPC2')]
  try:
    server_url = 'https://{lava_user:>s}:{lava_token:>s}@{lava_server:>s}'
    server_url = server_url.format(
      lava_user = args['lava_user'],
      lava_token = args['lava_token'],
      lava_server = args['lava_server'])
    server = xmlrpclib.ServerProxy(server_url)
    lava_job_id = server.scheduler.submit_job(config)
    if isinstance(lava_job_id, int):
      lava_url_id = lava_job_id
    else:
      lava_url_id = lava_job_id[0].partition('.')[0]
    print 'LAVA Job Id; %s, URL: https://%s/scheduler/job/%s' % \
      (lava_job_id, lava_server_root, lava_url_id)
    try:
      lava_sub_job_defs = map(lambda sub_job:
        json.loads(server.scheduler.job_details(sub_job)['definition']),
        lava_job_id)
      lava_sub_job_roles = collections.OrderedDict(
        map(lambda sub_job_def: [sub_job_def['sub_id'], sub_job_def['role']],
          lava_sub_job_defs))
      print 'LAVA Sub-Jobs: %s' % ','.join(map(lambda sub_job:
        sub_job + ':' + lava_sub_job_roles[sub_job], lava_sub_job_roles))
    except TypeError:
      pass
  except xmlrpclib.ProtocolError, e:
    print 'Error making a LAVA request:', obfuscate_credentials(str(e))
    sys.exit(1)

def add_sub(sub, substitutions):
  parts = sub.split('=', 1)
  if len(parts) != 2:
    print >> sys.stderr, 'Invalid setting: %s' % sub
    sys.exit(1)
  substitutions[parts[0].strip()] = parts[1].strip()

def main():
  parser = argparse.ArgumentParser( description='''Dispatch a benchmark run
                     into LAVA as a multinode job, optionally building it
                     first.''')
  parser.add_argument('overrides', nargs='*',
                      help='''NAME=VALUE pairs to set variables in the input
                              YAML. May be literal NAME=VALUE pairs and/or
                              names of files containing such pairs on
                              separate lines. Last value wins.''')
  parser.add_argument('--lava-server', default='lava.tcwglab/RPC2/',
                      help='LAVA server to dispatch to. Defaults to main Linaro instance.')
  parser.add_argument('--lava-user', default=os.environ['USER'],
                      help='LAVA user to dispatch as. Defaults to $USER.')
  parser.add_argument('--bundle-stream',
                      help='LAVA bundle stream to submit to. Defaults to /private/personal/<lava-user>')
  parser.add_argument('--benchmark', required=True,
                      choices=['CPU2000', 'CPU2006', 'EEMBC', 'Coremark-Pro',
                          'fakebench'],
                      help="Benchmark to build/run")
  parser.add_argument('--target-config', required=True, nargs='+',
                      help='''Target config(s) with which to run benchmark. May
                      be the name of the config (e.g. juno-a57), or a role:config
                      pair (e.g. big:juno-a57 little:juno-a53). You may specify
                      the same argument multiple times (e.g. big:juno-a57 big:juno-a57),
                      getting one instance of that role for each specification.
                      If no role is given, role=config. Script prefixes all
                      target roles with target- (e.g. big:juno-a57 results in
                      role target-big; juno-a57 results in role target-juno-a57).''')
  parser.add_argument('--host-device-type', default='kvm',
                      choices=['arndale', 'mustang', 'panda-es', 'juno', 'kvm'],
                      help="Host to build/dispatch benchmark. Role is always 'host'.")
  parser.add_argument('--prebuilt',
                      help='Prebuilt tarball of benchmark.')
  parser.add_argument('--toolchain',
                      help='Toolchain to build benchmark with.')
  #Strictly, TRIPLE does not have to be set, as unset means native. However, we
  #force user to be explicit here, given the length of time it takes to fail on
  #accidental unset of TRIPLE.
  parser.add_argument('--triple', required=True,
                      help='''Triple identifying target to build for and run
                              on. Set to 'native' for native build/run.''')
  parser.add_argument('--sysroot',
                      help='Sysroot to build benchmark with.')
  parser.add_argument('--compiler-flags',
                      help='Flags to pass to toolchain at build time.')
  parser.add_argument('--make-flags',
                      help='Flags to pass to make at build time.')
  parser.add_argument('--run-flags',
                      help="Flags for benchmark execution framework.")
  parser.add_argument('--tags', nargs='*',
                      help='''Tag(s) to use in device reservation. Give
                              role:tag pairs to set a tag for a role. May give
                              a default for all roles with no specific tag by
                              passing a value with no colon.''')
  parser.add_argument('--dry-run', action='store_true', default=False,
                      help="Show both stages of parsing, don't dispatch.")
  global args
  args = vars(parser.parse_args())

  #Post-process triple argument (will be validated by Benchmark.sh)
  if args['triple'] == 'native':
    args['triple'] = None

  #All of these values will be empty string if not explicitly set
  generator_inputs = {k.upper(): args[k] or '' for k in [
    'lava_server',
    'lava_user',
    'bundle_stream',
    'benchmark',
    'host_device_type',
    'prebuilt',
    'toolchain',
    'triple',
    'sysroot',
    'compiler_flags',
    'make_flags',
    'run_flags',
  ]}

  #Handle values that are not simple string/int types
  generator_inputs['TARGET_CONFIG'] = ' '.join(args['target_config'])

  tags = args['tags']
  if tags:
    #Confirm no duplicates - kinda harmless, but unlikely to be what user meant
    tags_set = set()
    for x in tags:
      if x in tags_set:
        print >> sys.stderr, '%s appears multiple times in --tags' % x
        sys.exit(1)
      tags_set.add(x)

    raw_host_tags = filter(lambda x: x.startswith('host:'), tags)
    if raw_host_tags:
      host_tags = map(lambda x: x[5:], raw_host_tags)
      target_tags = tags_set.difference(raw_host_tags)
    else:
      host_tags = filter(lambda x: not ':' in x, tags) #Assign any defaults to host_tags
      target_tags = tags
    generator_inputs['HOST_TAG'] = ' '.join(host_tags) #Note mismatched plurality - we let Benchmark.sh validate that there is actually only 1
    generator_inputs['TARGET_TAGS'] = ' '.join(target_tags)

  for override in args['overrides']:
    if os.path.isfile(override):
      if '=' in override:
        print 'Ambiguous argument: %s is a CLI substitution, but is also a file' % override
        sys.exit(1)
      else:
        with open(override) as f:
         for line in f:
           add_sub(line, generator_inputs)
    else:
      add_sub(override, generator_inputs)

  #Produce the YAML
  generator = subprocess.Popen(os.path.join(os.path.dirname(sys.argv[0]),
                                   'Benchmark.sh'), stdout=subprocess.PIPE,
                                   env=generator_inputs)
  config = generator.stdout.read()
  if generator.wait() != 0:
    print >> sys.stderr, 'Benchmark.sh failed'
    sys.exit(1)

  if args['dry_run']:
    print config

  #Produce the JSON
  config = json.dumps(yaml.safe_load(config), indent=2, separators=(',',': '))

  #Bail if that's the right thing to do
  if args['dry_run']:
    print config
    print
    print "--dry-run given, exiting without dispatch"
    sys.exit(0)

  #Get token from keyring
  args['lava_token'] = keyring.core.get_password("lava-tool-https://%s" %
          args['lava_server'], args['lava_user'])
  if not args['lava_token']:
    print >> sys.stderr, 'No token in keyring for %s on %s' % \
      (args['lava_user'], args['lava_server'])
    print >> sys.stderr, 'Expected to find token for %s on lava-tool-https://%s' % \
      (args['lava_user'], args['lava_server'])
    print >> sys.stderr, 'Check Benchmark.sh output, above, for warnings about LAVA_SERVER.'
    print >> sys.stderr, "Benchmark.sh cannot modify dispatch-benchmark's copy of LAVA_SERVER."
    sys.exit(1)

  #Dispatch the JSON
  dispatch(config)

if __name__ == '__main__':
  main()
