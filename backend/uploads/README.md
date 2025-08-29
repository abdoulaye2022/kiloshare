# Uploads Directory

This directory is used for storing uploaded files via FTP.

## Structure
- `avatars/` - User profile pictures
- `luggage/` - Luggage space images
- `documents/` - Identity documents and other files
- `temp/` - Temporary files during upload process

## Security
- Only specific file types are allowed (jpg, jpeg, png, gif, pdf)
- PHP execution is disabled in this directory
- Maximum file size is limited to 10MB
- Directory browsing is disabled

## Permissions
- Directory permissions: 755
- File permissions: 644

## FTP Configuration
Make sure your FTP server is configured to write to this directory with proper user permissions.