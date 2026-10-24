//! Embedded usbmuxd server (Linux + Windows).
//!
//! Runs the usbmuxd event loop on a background thread so `idevicerestore` (via
//! libusbmuxd) can reach USB devices for the restore-mode phase without an
//! external usbmuxd daemon. On Linux it listens on a private Unix socket; on
//! Windows uses private TCP `127.0.0.1:27016`, leaving Apple's listener untouched.

use std::ffi::CString;
use std::thread::{self, JoinHandle};

use crate::error::{Error, Result};
use crate::progress::{Event, ProgressFn};

// The C backend deliberately leaves stale USB transfer state for process-exit
// cleanup. Never reinitialize that state after a probe/restore in this process.
#[cfg(target_os = "windows")]
static WINDOWS_MUX_USED: std::sync::atomic::AtomicBool = std::sync::atomic::AtomicBool::new(false);

/// RAII guard that starts the embedded usbmuxd server and tears it down on drop.
pub struct UsbmuxdGuard {
    /// The Unix socket file to clean up (Linux only).
    #[cfg(target_os = "linux")]
    socket_path: std::path::PathBuf,
    thread: Option<JoinHandle<()>>,
    #[cfg(target_os = "windows")]
    previous_socket: Option<std::ffi::OsString>,
}

impl UsbmuxdGuard {
    /// Start the embedded usbmuxd server and point libusbmuxd at it.
    pub fn start(progress: ProgressFn) -> Result<Self> {
        #[cfg(target_os = "windows")]
        if WINDOWS_MUX_USED.swap(true, std::sync::atomic::Ordering::SeqCst) {
            return Err(Error::UsbmuxdFailed("private Windows mux is single-use; start a fresh process".into()));
        }
        progress(Event::UsbmuxdStarting);

        // The C server validates the exact private loopback endpoint on Windows.
        #[cfg(target_os = "linux")]
        let socket_path = {
            let path = std::path::PathBuf::from(format!(
                "/tmp/restorekit-usbmuxd-{}.sock",
                std::process::id()
            ));
            let _ = std::fs::remove_file(&path);
            path
        };
        #[cfg(target_os = "linux")]
        let start_arg = socket_path.to_string_lossy().into_owned();
        #[cfg(target_os = "windows")]
        let start_arg = String::from("127.0.0.1:27016");

        let path_c = CString::new(start_arg.as_bytes())
            .map_err(|_| Error::UsbmuxdFailed("socket path contains a NUL byte".into()))?;
        restorekit_sys::usbmuxd_start(&path_c).map_err(|rc| {
            Error::UsbmuxdFailed(format!("restorekit_usbmuxd_start returned {rc}"))
        })?;

        #[cfg(target_os = "windows")]
        let previous_socket = std::env::var_os("USBMUXD_SOCKET_ADDRESS");

        let thread_result = thread::Builder::new()
            .name("usbmuxd".into())
            .spawn(restorekit_sys::usbmuxd_run);
        let thread = match thread_result {
            Ok(thread) => thread,
            Err(error) => {
                restorekit_sys::usbmuxd_stop();
                restorekit_sys::usbmuxd_cleanup();
                return Err(Error::UsbmuxdFailed(format!("failed to spawn usbmuxd thread: {error}")));
            }
        };
        #[cfg(target_os = "windows")]
        unsafe { std::env::set_var("USBMUXD_SOCKET_ADDRESS", "127.0.0.1:27016") };

        // Linux uses a private Unix socket; Windows env is set above and restored on Drop.
        #[cfg(target_os = "linux")]
        unsafe {
            std::env::set_var(
                "USBMUXD_SOCKET_ADDRESS",
                format!("UNIX:{}", socket_path.display()),
            );
        }

        // Give the listener a moment to come up.
        #[cfg(target_os = "linux")]
        {
            for _ in 0..50 {
                if socket_path.exists() {
                    break;
                }
                std::thread::sleep(std::time::Duration::from_millis(100));
            }
        }
        #[cfg(target_os = "windows")]
        std::thread::sleep(std::time::Duration::from_millis(200));

        Ok(Self {
            #[cfg(target_os = "linux")]
            socket_path,
            thread: Some(thread),
            #[cfg(target_os = "windows")]
            previous_socket,
        })
    }
}

impl Drop for UsbmuxdGuard {
    fn drop(&mut self) {
        // Signal the event loop to exit, then wait for the thread.
        restorekit_sys::usbmuxd_stop();
        if let Some(handle) = self.thread.take() {
            let _ = handle.join();
        }
        restorekit_sys::usbmuxd_cleanup();
        #[cfg(target_os = "windows")]
        unsafe {
            match &self.previous_socket {
                Some(value) => std::env::set_var("USBMUXD_SOCKET_ADDRESS", value),
                None => std::env::remove_var("USBMUXD_SOCKET_ADDRESS"),
            }
        }

        #[cfg(target_os = "linux")]
        {
            let _ = std::fs::remove_file(&self.socket_path);
            unsafe {
                std::env::remove_var("USBMUXD_SOCKET_ADDRESS");
            }
        }
    }
}
