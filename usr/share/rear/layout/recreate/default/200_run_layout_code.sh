#
# Run the disk layout recreation code (diskrestore.sh)
# again and again until it succeeds or the user aborts.
#
# TODO: Provide a skip option (needs thoughtful consideration)
# I <jsmeix@suse.de> think such an option is not needed in practice
# because the user can add an initial 'exit 0' line to diskrestore.sh
# that results in practice the same behaviour.
#
# TODO: Implement layout/prepare as part of a function ?
#
# TODO: Add choices as in layout/prepare/default/500_confirm_layout_file.sh
#  "View disk layout ($LAYOUT_FILE)"
#  "Edit disk layout ($LAYOUT_FILE)"
# and for the latter choice some code like
#   If disklayout.conf has changed, generate new diskrestore.sh
#     if (( $timestamp < $(stat --format="%Y" $LAYOUT_FILE) )); then
#         LogPrint "Detected changes to $LAYOUT_FILE, rebuild $LAYOUT_CODE on-the-fly."
#         SourceStage "layout/prepare" 2>>$RUNTIME_LOGFILE
#     fi
#

rear_workflow="rear $WORKFLOW"
original_disk_space_usage_file="$VAR_DIR/layout/config/df.txt"
rear_shell_history="$( echo -e "cd $VAR_DIR/layout/\nvi $LAYOUT_CODE\nless $RUNTIME_LOGFILE" )"
unset choices
choices[0]="Rerun disk recreation script ($LAYOUT_CODE)"
choices[1]="View '$rear_workflow' log file ($RUNTIME_LOGFILE)"
choices[2]="Edit disk recreation script ($LAYOUT_CODE)"
choices[3]="View original disk space usage ($original_disk_space_usage_file)"
choices[4]="Use Relax-and-Recover shell and return back to here"
choices[5]="Abort '$rear_workflow'"
prompt="The disk layout recreation script failed"
choice=""
wilful_input=""
# When USER_INPUT_LAYOUT_RUN has any 'true' value be liberal in what you accept and
# assume choices[0] 'Run disk recreation script again' was actually meant:
is_true "$USER_INPUT_LAYOUT_CODE_RUN" && USER_INPUT_LAYOUT_CODE_RUN="${choices[0]}"

# Run the disk layout recreation code (diskrestore.sh)
# again and again until it succeeds or the user aborts:
while true ; do
    # Run LAYOUT_CODE in a sub-shell because it sets 'set -e'
    # so that it exits the running shell in case of an error
    # but that exit must not exit this running bash here:
    ( source $LAYOUT_CODE )
    # One must explicitly test $? (the exit status of the most recently executed foreground pipeline)
    # whether or not $? is zero because somehow in this particular case here code like
    #   ( source $LAYOUT_CODE ) && break
    # does not work because it seems this way the 'set -e' inside LAYOUT_CODE does no longer work
    # (i.e. then LAYOUT_CODE would no longer exit if a command therein exits with non-zero status)
    # but on plain command line a sourced script with 'set -e' inside works this way:
    #   # echo 'set -e ; cat qqq ; echo hello' >script.sh
    #   # ( source script.sh ) && echo ok || echo failed
    #   cat: qqq: No such file or directory
    #   failed
    #   # echo QQQ >qqq
    #   # ( source script.sh ) && echo ok || echo failed
    #   QQQ
    #   hello
    #   ok
    # FIXME: Provide an explanatory comment what the reason is why it behaves this way here.
    # Break the outer while loop when LAYOUT_CODE succeeded:
    (( $? == 0 )) && break
    # Run an inner while loop with a user dialog so that the user can fix things when LAYOUT_CODE failed.
    # Such a fix does not necessarily mean the user must change the diskrestore.sh script.
    # The user might also fix things by only using the Relax-and-Recover shell.
    while true ; do
        choice="$( UserInput -I LAYOUT_CODE_RUN -p "$prompt" -D "${choices[0]}" "${choices[@]}" )" && wilful_input="yes" || wilful_input="no"
        case "$choice" in
            (${choices[0]})
                # Rerun disk recreation script:
                is_true "$wilful_input" && LogPrint "User reruns disk recreation script" || LogPrint "Rerunning disk recreation script by default"
                # Only break the inner while loop (i.e. the user dialog loop):
                break
                ;;
            (${choices[1]})
                # Run 'less' with the original STDIN STDOUT and STDERR when 'rear' was launched by the user:
                less $RUNTIME_LOGFILE 0<&6 1>&7 2>&8
                ;;
            (${choices[2]})
                # Run 'vi' with the original STDIN STDOUT and STDERR when 'rear' was launched by the user:
                vi $LAYOUT_CODE 0<&6 1>&7 2>&8
                ;;
            (${choices[3]})
                # Run 'less' with the original STDIN STDOUT and STDERR when 'rear' was launched by the user:
                less $original_disk_space_usage_file 0<&6 1>&7 2>&8
                ;;
            (${choices[4]})
                # rear_shell runs 'bash' with the original STDIN STDOUT and STDERR when 'rear' was launched by the user:
                rear_shell "" "$rear_shell_history"
                ;;
            (${choices[5]})
                abort_recreate
                Error "User chose to abort '$rear_workflow' in ${BASH_SOURCE[0]}"
                ;;
        esac
    done
done

