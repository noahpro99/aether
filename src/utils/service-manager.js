import GLib from 'gi://GLib';

/**
 * Service Manager - Handles checking system services and restarting desktop components
 *
 * This module provides utilities for:
 * - Checking if omarchy theme system is installed
 * - Restarting swaybg wallpaper service
 */

/**
 * Checks if omarchy is installed by looking for the omarchy-theme-set command
 * @returns {boolean} True if omarchy is available
 */
export function isOmarchyInstalled() {
    try {
        const [success] = GLib.spawn_command_line_sync(
            'which omarchy-theme-set'
        );
        return success;
    } catch (e) {
        return false;
    }
}

/**
 * Checks if a process is running
 * @param {string} processName - Name of the process
 * @returns {boolean} True if running
 */
export function isProcessRunning(processName) {
    try {
        const [success, stdout] = GLib.spawn_command_line_sync(
            `pgrep -x ${processName}`
        );
        return success && stdout.length > 0;
    } catch (e) {
        return false;
    }
}

/**
 * Reloads the wallpaper service (swaybg or hyprpaper)
 * @returns {boolean} Success status
 */
export function reloadWallpaper() {
    try {
        // Use the symlink path that omarchy uses
        const backgroundLink = GLib.build_filenamev([
            GLib.get_home_dir(),
            '.config',
            'omarchy',
            'current',
            'background',
        ]);

        console.log(
            'Reloading wallpaper with background link:',
            backgroundLink
        );

        // Check if hyprpaper is running
        if (isProcessRunning('hyprpaper')) {
            console.log('Hyprpaper detected, updating via hyprctl...');
            // We need to preload and then set the wallpaper
            // hyprpaper requires absolute paths, but backgroundLink is already absolute
            GLib.spawn_command_line_async(
                `hyprctl hyprpaper preload "${backgroundLink}"`
            );
            GLib.spawn_command_line_async(
                `hyprctl hyprpaper wallpaper ", ${backgroundLink}"`
            );
            return true;
        }

        // Fallback to swaybg (original behavior)
        console.log('Restarting swaybg...');
        // Kill existing swaybg process
        GLib.spawn_command_line_async('pkill -x swaybg');

        // Start swaybg using uwsm-app like omarchy does
        // setsid is used to detach from the current session
        GLib.spawn_command_line_async(
            `setsid uwsm-app -- swaybg -i "${backgroundLink}" -m fill`
        );

        return true;
    } catch (e) {
        console.error('Error reloading wallpaper:', e.message);
        return false;
    }
}

/**
 * Restarts swaybg wallpaper service with a new wallpaper
 * @deprecated Use reloadWallpaper() instead
 * @returns {boolean} Success status
 */
export function restartSwaybg() {
    return reloadWallpaper();
}
