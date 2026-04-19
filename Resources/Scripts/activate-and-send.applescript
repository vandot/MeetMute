set frontApp to path to frontmost application as text
tell application "System Events"
    set frontmost of (first process whose bundle identifier is "{{BUNDLE_ID}}") to true
end tell
repeat with i from 1 to 20
    if frontmost of (first process whose bundle identifier is "{{BUNDLE_ID}}") then exit repeat
    delay 0.05
end repeat
tell application "System Events"
    tell (first process whose bundle identifier is "{{BUNDLE_ID}}")
        {{KEYSTROKE}}
    end tell
end tell
delay 0.1
tell application frontApp to activate
