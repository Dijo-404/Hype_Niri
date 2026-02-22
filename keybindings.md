# ⌨️ Niri Keybindings

These are the primary default keybindings for the Hype Niri environment.

> [!NOTE]  
> The "Super" key refers to the Windows, Command, or Meta key on your keyboard.

## 🪟 Window Management

| Keybinding | Action | Description |
| :--- | :--- | :--- |
| `Super + Q` | `close-window` | Close active window |
| `Ctrl + Q` | `close-window` | Close active window |
| `Alt + F4` | `close-window` | Close active window |
| `Super + Delete` | `quit` | Exit Niri completely |
| `Super + W` | `toggle-column-tabbed` | Toggle tabbed column view |
| `Super + Shift + F` | `fullscreen-window` | Toggle fullscreen mode |
| `Super + F` | `maximize-column` | Maximize the current column |
| `Super + O` | `toggle-overview` | Toggle window overview |
| `Super + Space` | `toggle-window-floating` | Toggle floating mode for a window |
| `Super + Shift + Space` | `switch-focus` | Switch focus between floating/tiling |
| `Super + L` | `hyprlock` | Lock the screen |

## 🎯 Focus & Navigation

| Keybinding | Action | Description |
| :--- | :--- | :--- |
| `Super + ←` / `→` | `focus-column` | Focus left/right column |
| `Super + ↑` / `↓` | `focus-window` | Focus up/down window within a column |
| `Alt + Tab` | `focus-window-down` | Cycle focus down |

## 📐 Resize

| Keybinding | Action | Description |
| :--- | :--- | :--- |
| `Super + Ctrl + ←` / `→` | `set-column-width ±30` | Resize column width coarsely |
| `Super + Ctrl + ↑` / `↓` | `set-window-height ±30` | Resize window height coarsely |
| `Super + -` / `=` | `set-column-width ±10%` | Adjust column width precisely |
| `Super + Shift + -` / `=`| `set-window-height ±10%` | Adjust window height precisely |

## 🚚 Move Window / Column

| Keybinding | Action | Description |
| :--- | :--- | :--- |
| `Alt + Shift + ←` / `→` | `move-column` | Move entire column left/right |
| `Alt + Shift + ↑` / `↓` | `move-window` | Move window up/down within column |

## 🏗️ Column Management

| Keybinding | Action | Description |
| :--- | :--- | :--- |
| `Super + R` | `switch-preset-width` | Cycle through preset column widths |
| `Super + Shift + R` | `switch-preset-height` | Cycle through preset window heights |
| `Super + Ctrl + R` | `reset-window-height`| Reset window to default height |
| `Super + Ctrl + F` | `expand-column` | Expand column to consume available width |
| `Super + Shift + C` | `center-column` | Center the active column on screen |
| `Super + [` | `consume/expel-left` | Consume or expel window to the left |
| `Super + ]` | `consume/expel-right` | Consume or expel window to the right |
| `Super + ,` | `consume-window` | Consume window into current column |

## 🚀 Applications & Launchers

| Keybinding | Action | Description |
| :--- | :--- | :--- |
| `Super + T` | `alacritty` | Launch Terminal |
| `Super + E` | `nautilus` | Launch File Manager |
| `Super + C` | `nvim` | Launch Neovim |
| `Super + B` | `firefox` | Launch Browser |
| `Ctrl + Shift + Esc`| `htop` | Launch System Monitor |
| `Super + A` | `fuzzel` | Launch Application Menu |
| `Super + Tab` | `toggle-overview` | Open Window Overview |
| `Super + .` | `bemoji` | Open Emoji Picker |
| `Super + V` | `cliphist` | Open Clipboard History List |

## 🔊 Audio & Brightness

| Keybinding | Action | Description |
| :--- | :--- | :--- |
| `F10` / `Mute` | `volume mute` | Toggle Audio Mute |
| `F11` / `Vol Down` | `volume down` | Decrease Volume |
| `F12` / `Vol Up` | `volume up` | Increase Volume |
| `Mic Mute` | `mic mute` | Toggle Microphone Mute |
| `F5` / `Bright Down`| `brightness down` | Decrease Screen Brightness |
| `F6` / `Bright Up` | `brightness up` | Increase Screen Brightness |
| `Play/Pause/Next/Prev`| `playerctl` | Control Media Playback |

## 🖥️ Workspaces & Monitors

| Keybinding | Action | Description |
| :--- | :--- | :--- |
| `Super + 1-0` | `focus-workspace` | Switch to workspace 1-10 |
| `Super + Shift + 1-0` | `move-to-workspace`| Move window to workspace 1-10 |
| `Super + PageDown/Up` | `focus-workspace` | Navigate workspaces up/down |
| `Super + Scroll` | `focus-workspace` | Scroll through workspaces |
| `Super + Shift + ←/→` | `focus-monitor` | Focus left/right monitor |
| `Super + Shift + Alt + ←/→`| `move-to-monitor` | Move column to left/right monitor |

## 📸 Screenshots & Pickers

| Keybinding | Action | Description |
| :--- | :--- | :--- |
| `Print` | `screenshot` | Interactive region screenshot |
| `Ctrl + Print` | `screenshot-screen` | Screenshot entire screen |
| `Alt + Print` | `screenshot-window` | Screenshot active window |
| `Super + Shift + P` | `hyprpicker` | Interactive color picker |

## 🎨 Miscellaneous

| Keybinding | Action | Description |
| :--- | :--- | :--- |
| `Super + Alt + ←` / `→` | `wallpaper random` | Cycle random wallpaper next/prev |
| `Super + Shift + W` | `wallpaper select` | Open wallpaper selector menu |
| `Super + Alt + ↑` / `↓` | `waybar restart` | Restart Waybar process |
| `Super + Esc` | `inhibit-shortcuts` | Toggle Niri keyboard shortcut override |
| `Power Button` | `wlogout` | Open power/logout menu |
