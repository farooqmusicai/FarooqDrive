# FarooqDrive End-User Guide

## Install
Download the official FarooqDrive installer or install FarooqDrive from Microsoft Store. Double-click the installer, complete the Windows prompts, and launch FarooqDrive from the Desktop or Start menu. You do not need Docker, Node.js, MySQL, a command prompt, or programming tools.

## First sign-in
Create a local FarooqDrive profile with email/password, or choose **Continue with Google**. Google authorization opens in your normal browser. Select the Google account and approve the requested access. Return to FarooqDrive when the browser confirms the connection.

## Add more Google Drives
Open the dashboard and choose **Add Drive account**. Authorize another Google account in your browser. The dashboard then combines the available quota information from connected accounts.

## Upload
Choose **Upload files**. FarooqDrive asks its local service to choose a connected account with enough available quota, then uses a Google Drive resumable upload session. Upload progress appears in the bottom-right panel.

## Files and virtual folders
FarooqDrive creates or uses a folder named `Farooqdrive` inside each connected Google Drive. Virtual folders shown in FarooqDrive are local organization metadata, so one virtual folder can contain files stored on several Google accounts.

## Sync
Choose **Sync** to read the Farooqdrive folder metadata from each connected account and reconcile the local database. Sync does not intentionally download the full file contents.

## Disconnect an account
Use the disconnect button on an account card. Files remain in Google Drive. You can also revoke FarooqDrive from your Google Account security settings.
