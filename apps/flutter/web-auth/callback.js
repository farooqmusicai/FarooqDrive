import {broadcastResponseToMainFrame} from '@azure/msal-browser/redirect-bridge';
broadcastResponseToMainFrame().catch(()=>{document.body.textContent='Sign-in could not finish. Close this window and retry from FarooqDrive.';});
