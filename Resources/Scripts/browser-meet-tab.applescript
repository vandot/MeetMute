set frontApp to path to frontmost application as text
set frontIsBrowser to (frontApp contains "{{APP_NAME}}")
{{TAB_SWITCH_BLOCK}}
if foundTab then
    delay 0.2
    tell application "System Events"
        tell application process "{{APP_NAME}}"
            {{KEYSTROKE}}
        end tell
    end tell
    delay 0.1
    {{RESTORE_BLOCK}}
end if
