set frontApp to path to frontmost application as text
tell application "{{APP_NAME}}" to activate
delay 0.2
tell application "System Events"
    tell application process "{{APP_NAME}}"
        {{KEYSTROKE}}
    end tell
end tell
delay 0.1
tell application frontApp to activate
