set frontApp to path to frontmost application as text
tell application "System Events"
    set frontmost of (first process whose bundle identifier is "{{BUNDLE_ID}}") to true
    tell (first process whose bundle identifier is "{{BUNDLE_ID}}")
        set windowMenu to menu 1 of menu bar item "Window" of menu bar 1
        set allItems to every menu item of windowMenu
        repeat with mi in allItems
            set miName to name of mi
            if miName is not missing value and miName does not start with "{{EXCLUDE_PREFIX}}" and miName contains "{{APP_NAME}}" then
                click mi
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
tell application frontApp to activate
