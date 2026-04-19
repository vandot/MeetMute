set frontApp to path to frontmost application as text
set frontIsTarget to (frontApp contains "{{APP_NAME}}")
tell application "{{APP_NAME}}" to activate
delay 0.3
tell application "System Events"
    tell (first process whose bundle identifier is "{{BUNDLE_ID}}")
        set origWindowName to ""
        if frontIsTarget and (count of windows) > 0 then
            set origWindowName to name of front window
        end if
        repeat with w in windows
            if name of w starts with "{{WINDOW_PREFIX}}" then
                perform action "AXRaise" of w
                exit repeat
            end if
        end repeat
    end tell
end tell
delay 0.2
tell application "System Events"
    tell (first process whose bundle identifier is "{{BUNDLE_ID}}")
        {{KEYSTROKE}}
    end tell
end tell
delay 0.1
if frontIsTarget and origWindowName is not "" then
    tell application "System Events"
        tell (first process whose bundle identifier is "{{BUNDLE_ID}}")
            repeat with w in windows
                if name of w is origWindowName then
                    perform action "AXRaise" of w
                    exit repeat
                end if
            end repeat
        end tell
    end tell
else
    tell application frontApp to activate
end if
