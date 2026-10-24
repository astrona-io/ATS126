#!/usr/bin/env bash
# PASS when the Pipeline release-notes runs lint and spellcheck after fetch
# only (not after each other), publish passes channel from the Pipeline
# parameter, and the Task publish-notes still has no default for channel.
set -uo pipefail

NS="starfleet"

lint_after="$(kubectl -n "$NS" get pipeline release-notes -o jsonpath='{.spec.tasks[?(@.name=="lint")].runAfter[*]}' 2>/dev/null)"
spell_after="$(kubectl -n "$NS" get pipeline release-notes -o jsonpath='{.spec.tasks[?(@.name=="spellcheck")].runAfter[*]}' 2>/dev/null)"
case " $spell_after " in
  *" lint "*)
    echo "FAIL: spellcheck still runs after lint (runAfter: '$spell_after'). The two checks only need fetch."
    exit 1 ;;
esac
case " $lint_after " in
  *" spellcheck "*)
    echo "FAIL: lint runs after spellcheck (runAfter: '$lint_after'). The two checks only need fetch."
    exit 1 ;;
esac
case " $spell_after " in
  *" fetch "*) ;;
  *)
    echo "FAIL: spellcheck must run after fetch, which writes notes.md (runAfter: '${spell_after}')."
    exit 1 ;;
esac

channel_value="$(kubectl -n "$NS" get pipeline release-notes -o jsonpath='{.spec.tasks[?(@.name=="publish")].params[?(@.name=="channel")].value}')"
if [ "$channel_value" != '$(params.channel)' ]; then
  echo "FAIL: the pipeline task publish must pass channel = \$(params.channel) (found '${channel_value}')."
  exit 1
fi

task_default="$(kubectl -n "$NS" get task publish-notes -o jsonpath='{.spec.params[?(@.name=="channel")].default}')"
if [ -n "$task_default" ]; then
  echo "FAIL: the Task publish-notes must not get a default for channel (found '$task_default'). Pass the value from the Pipeline instead."
  exit 1
fi

echo "PASS: lint and spellcheck both run after fetch only, and publish passes channel from the Pipeline."
exit 0
