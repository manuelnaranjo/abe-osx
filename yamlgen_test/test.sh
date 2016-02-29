#!/bin/bash
set -ue
set -o pipefail

exec {stdout_save}>&1

function clean {
  exec 1>&${stdout_save}
  exec {stdout_save}>&-
  if test -n "${output_dir:-}"; then
    if test -d "${output_dir}"; then
      rm -rf "${output_dir}" >&2
    fi
  fi
}

trap clean EXIT

if test -z "${viewer:-}"; then
  echo "To get a visual diff, set viewer. For example: viewer=meld $0"
fi

basedir="`dirname $0`"
output_dir="`mktemp -dt multitarget-XXXXX`"
for x in "${basedir}"/dispatchers/*; do
  exec 1>"${output_dir}/`basename $x .sh`"
  $x | sed '/^[[:blank:]]*$/d' #Don't care about blank lines
done
exec 1>&${stdout_save}

declare -a bad
golddir="${basedir}/gold"
total="`ls ${output_dir} | wc -l`"
for x in `ls ${output_dir}`; do
  files=("${golddir}/${x}" "${output_dir}/${x}")
  if ! diff -q "${files[@]}"; then
    if test -z "${bad:-}"; then
      bad=("${x}")
    else
      bad=("${bad[@]}" "${x}")
    fi
  fi
done
if test -z "${bad:-}"; then
  echo "All ${total} files passed comparison"
else
  echo "${#bad[@]} of ${total} files failed comparison"
  if test -n "${viewer:-}"; then
    echo "Running failing cases through $viewer."
    echo "To stop, stop the process (Ctrl-Z), then kill the stopped job (kill %<jobno>)."
    for x in "${bad[@]}"; do
      ${viewer} "${golddir}/${x}" "${output_dir}/${x}"
    done
  fi
fi

