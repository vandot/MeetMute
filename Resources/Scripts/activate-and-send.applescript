set frontApp to path to frontmost application as text
tell application "System Events"
    set frontmost of (first process whose bundle identifier is "{{BUNDLE_ID}}") to true
end tell
delay 0.2
tell application "System Events"
    tell (first process whose bundle identifier is "{{BUNDLE_ID}}")
        {{KEYSTROKE}}
    end tell
end tell
delay 0.1
tell application frontApp to activate
