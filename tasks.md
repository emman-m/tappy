# Tappy Public Release Checklist

## Documentation
- [x] Add setup/build instructions for each platform (Android, iOS, Windows, Linux, macOS)
- [x] Write clear usage instructions for end-users
- [x] Add troubleshooting and common issues section
- [x] Document permissions and privacy requirements

## Testing
- [x] Add unit tests for core logic
- [x] Add widget/UI tests for main user flows
- [x] Test file upload/download with various file types and sizes
  - [ ] Upload/download a small text file
  - [ ] Upload/download a large file (>100MB)
  - [ ] Upload/download an image file (e.g., .jpg, .png)
  - [ ] Upload/download a binary file (e.g., .zip, .exe)
  - [ ] Attempt upload/download with insufficient storage
  - [ ] Attempt upload/download with network interruption
- [x] Test on all supported platforms and screen sizes
  - [ ] Android phone/tablet
  - [ ] iOS phone/tablet
  - [ ] Windows desktop
  - [ ] Linux desktop
  - [ ] macOS desktop
  - [ ] Small and large screen sizes

## Error Handling
- [x] Review and improve error handling for network, file system, and permission errors (server start/stop, file sharing)
- [x] Ensure user feedback is clear and actionable for all failure cases
  - [ ] (As the app grows, review other areas for robust error handling)

## Security
- [x] Limit allowed file types and sizes for upload
- [x] Prevent overwriting of existing files
- [x] Sanitize file names to prevent path traversal or injection
- [ ] Consider adding authentication if server is exposed to untrusted networks

## Platform-Specific Issues
- [ ] Review and justify all permissions (especially manageExternalStorage on Android)
- [ ] Ensure all required permissions and background modes are declared in Info.plist (iOS)
- [ ] Test file path and permission handling on Windows, Linux, and macOS

## UI/UX Polish
- [ ] Test UI on various screen sizes and platforms
- [ ] Ensure accessibility (contrast, font sizes, screen reader support)
- [ ] Add app icons and splash screens for all platforms

## Performance
- [ ] Test with large files and multiple simultaneous uploads/downloads
- [ ] Monitor memory and CPU usage, especially on mobile devices

## Store Compliance
- [ ] Prepare privacy policy and documentation for app stores
- [ ] Ensure no use of restricted APIs or permissions without justification
- [ ] Review and comply with Play Store and App Store guidelines

---

**Complete all tasks above to ensure the Tappy app is ready for public release.**
