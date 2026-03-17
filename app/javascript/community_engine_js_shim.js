// ESM shim: re-export from the UMD global populated by community-engine.umd.js
// The importmap loads community-engine.umd.js first (under the name
// community_engine_js_umd), which populates globalThis.CommunityEngine.
// This shim re-exports every named export so Stimulus controllers can use
// standard ESM named imports from 'community_engine_js'.
const CE = globalThis.CommunityEngine ?? {}
export const {
  initializeV1Session,
  clearV1SessionCache,
  encryptMessage,
  decryptMessage,
  encryptGroupMessage,
  decryptGroupMessage,
  createSenderKeyDistribution,
  processSenderKeyDistribution,
  generateIdentity,
  hasLocalIdentity,
  registerPrekeys,
  fetchPrekeyBundle,
  getLocalIdentity,
  getAllPreKeys,
  getAllSignedPreKeys,
  exportKeyBackup,
  importKeyBackup,
  hasSession,
  initOutboundSession,
  fetchParticipantBundles,
} = CE
export default CE
