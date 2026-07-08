on run argv
    set volumeName to item 1 of argv
    set appName to item 2 of argv
    set backgroundPath to "/Volumes/" & volumeName & "/.background/background.png"

    tell application "Finder"
        tell disk volumeName
            open
            delay 1

            set installerWindow to container window
            set current view of installerWindow to icon view
            set toolbar visible of installerWindow to false
            set statusbar visible of installerWindow to false
            set bounds of installerWindow to {160, 120, 880, 560}

            set viewOptions to icon view options of installerWindow
            set arrangement of viewOptions to not arranged
            set icon size of viewOptions to 104
            set text size of viewOptions to 13
            set background picture of viewOptions to (POSIX file backgroundPath as alias)

            set position of item (appName & ".app") of container window to {190, 246}
            set position of item "Applications" of container window to {530, 246}

            update without registering applications
            delay 1
            close installerWindow
        end tell
    end tell
end run
