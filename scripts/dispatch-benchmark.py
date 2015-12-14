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

def yaml_to_json(yaml_file, substitutions):
  with open(yaml_file) as f:
    template = string.Template(f.read())

  placeholders = map(lambda match: match.group('named', 'braced'),
                     string.Template.pattern.finditer(template.template))
  placeholders = set(filter(None, itertools.chain(*placeholders)))

  try:
    lava_template = template.substitute(substitutions)
  except KeyError as e:
    print >> sys.stderr, "No substitution available for %s" % e.args[0]
    print >> sys.stderr, "Available substitutions:"
    for x in sorted(substitutions):
      print >> sys.stderr, "%s -> '%s'" % (x, substitutions[x])
    sys.exit(1)

  unused = set(substitutions).difference(placeholders)
  if unused:
    print >> sys.stderr, "Unusued substitutions:"
    for x in sorted(unused):
      print >> sys.stderr, "%s -> '%s'" % (x, substitutions[x])
    sys.exit(1)

  if args['dry_run']:
    print lava_template

  try:
    config = json.dumps(yaml.safe_load(lava_template), indent=2, separators=(',',': '))
  except:
    print >> sys.stderr, "Failed to convert YAML to JSON"
    print >> sys.stderr, "YAML input was:"
    print >> sys.stderr, lava_template
    print >> sys.stderr
    print >> sys.stderr, "Original exception was:"
    raise

  if args['dry_run']:
    print config
  return config

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
  parser.add_argument('--template', required=True,
                      help="YAML jobdef containing substitutions to be made")
  parser.add_argument('--lava-server', default='validation.linaro.org/RPC2/',
                      help='LAVA server to dispatch to. Defaults to main Linaro instance.')
  parser.add_argument('--lava-user', default=os.environ['USER'],
                      help='LAVA user to dispatch as. Defaults to $USER.')
  parser.add_argument('--bundle-stream',
                      help='LAVA bundle stream to submit to. Defaults to /private/personal/<lava-user>')
  parser.add_argument('--benchmark', required=True,
                      choices=['CPU2000', 'CPU2006', 'EEMBC', 'CoremarkPro',
                          'fakebench'],
                      help="Benchmark to build/run")
  parser.add_argument('--target-config', required=True,
                      choices=['arndale', 'mustang', 'panda-es', 'juno-a53',
                               'juno-a57', 'kvm'],
                      help="Target config with which to run benchmark.")
  parser.add_argument('--prebuilt',
                      help='Prebuilt tarball of benchmark.')
  parser.add_argument('--toolchain',
                      help='Toolchain to build benchmark with.')
  parser.add_argument('--sysroot',
                      help='Sysroot to build benchmark with.')
  parser.add_argument('--compiler-flags',
                      help='Flags to pass to toolchain at build time.')
  parser.add_argument('--make-flags',
                      help='Flags to pass to make at build time.')
  parser.add_argument('--run-flags',
                      help="Flags for benchmark execution framework.")
  parser.add_argument('--dry-run', action='store_true', default=False,
                      help="Show both stages of parsing, don't dispatch.")
  global args
  args = vars(parser.parse_args())

  #Get token from keyring
  args['lava_token'] = keyring.core.get_password("lava-tool-https://%s" %
          args['lava_server'], args['lava_user'])
  if not args['lava_token']:
    print >> sys.stderr, 'No token in keyring for %s on %s' % \
      (args['lava_user'], args['lava_server'])
    sys.exit(1)

  #Set post-parse defaults
  if not args['bundle_stream']:
    args['bundle_stream'] = '/private/personal/%s/' % args['lava_user']

  #All of these values will be empty string if not explicitly set
  var_generator_inputs = {k.upper(): args[k] or '' for k in [
    'lava_server',
    'lava_user',
    'bundle_stream',
    'benchmark',
    'target_config',
    'prebuilt',
    'toolchain',
    'sysroot',
    'compiler_flags',
    'make_flags',
    'run_flags',
  ]}
  var_generator = subprocess.Popen(os.path.join(os.path.dirname(sys.argv[0]),
                                   'Benchmark.sh'), stdout=subprocess.PIPE,
                                   env=var_generator_inputs)
  substitutions={}
  for line in iter(var_generator.stdout.readline, ''):
    add_sub(line, substitutions)

  for override in args['overrides']:
    if os.path.isfile(override):
      if '=' in override:
        print 'Ambiguous argument: %s is a CLI substitution, but is also a file' % override
        sys.exit(1)
      else:
        with open(override) as f:
         for line in f:
           add_sub(line, substitutions)
    else:
      add_sub(override, substitutions)

  #Validate inputs
  if (not substitutions['TOOLCHAIN'] and not substitutions['PREBUILT']):
    print >> sys.stderr, 'Must give exactly one of --toolchain and --prebuilt.'
    sys.exit(1)
  if substitutions['PREBUILT']:
    bad_flags = filter(lambda x: substitutions[x], \
                       ('TOOLCHAIN', 'COMPILER_FLAGS', 'MAKE_FLAGS'))
    if bad_flags:
      for flag in bad_flags:
        print >> sys.stderr, 'Must not specify %s with --prebuilt' % flag
      sys.exit(1)
  if substitutions['SYSROOT'] and not substitutions['TOOLCHAIN']:
    print >> sys.stderr, '--sysroot only makes sense with --toolchain'
    sys.exit(1)

  config=yaml_to_json(args['template'], substitutions)
  if args['dry_run']:
    print
    print "--dry-run given, exiting without dispatch"
    sys.exit(0)

  dispatch(config)

if __name__ == '__main__':
  main()
