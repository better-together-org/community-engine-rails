// ESM shim — wraps the UMD global so Stimulus controllers can use named imports.
// Side-effect import: loads the UMD bundle so globalThis.CommunityEngine is populated
// before any of the lazy getters below are invoked.
import 'community_engine_js_umd'
// Getters are lazy: resolved when the function is *called*, not when the module loads,
// so the UMD bundle is guaranteed to have run by then.
//
// Symbols confirmed present in community-engine.umd.js exports (2026-03-17):
//   clearKeystore, createSenderKeyDistribution, decryptGroupMessage, decryptMessage,
//   encryptGroupMessage, encryptMessage, exportKeyBackup, fetchParticipantBundles,
//   fetchPrekeyBundle, formatPersonName, generateIdentity, getAllPreKeys,
//   getAllSignedPreKeys, getLocalIdentity, hasLocalIdentity, hasSession,
//   importKeyBackup, initOutboundSession, processSenderKeyDistribution,
//   registerPrekeys, truncate
//
// Symbols NOT present in the UMD bundle (stubs — return undefined gracefully via
// optional chaining below):
//   initializeV1Session, clearV1SessionCache
const ce = () => globalThis.CommunityEngine ?? {}

export const initializeV1Session              = (...args) => ce().initializeV1Session?.(...args)
export const clearV1SessionCache              = (...args) => ce().clearV1SessionCache?.(...args)
export const encryptMessage                   = (...args) => ce().encryptMessage?.(...args)
export const decryptMessage                   = (...args) => ce().decryptMessage?.(...args)
export const encryptGroupMessage              = (...args) => ce().encryptGroupMessage?.(...args)
export const decryptGroupMessage              = (...args) => ce().decryptGroupMessage?.(...args)
export const createSenderKeyDistribution      = (...args) => ce().createSenderKeyDistribution?.(...args)
export const processSenderKeyDistribution     = (...args) => ce().processSenderKeyDistribution?.(...args)
export const generateIdentity                 = (...args) => ce().generateIdentity?.(...args)
export const hasLocalIdentity                 = (...args) => ce().hasLocalIdentity?.(...args)
export const registerPrekeys                  = (...args) => ce().registerPrekeys?.(...args)
export const fetchPrekeyBundle                = (...args) => ce().fetchPrekeyBundle?.(...args)
export const getLocalIdentity                 = (...args) => ce().getLocalIdentity?.(...args)
export const getAllPreKeys                     = (...args) => ce().getAllPreKeys?.(...args)
export const getAllSignedPreKeys               = (...args) => ce().getAllSignedPreKeys?.(...args)
export const exportKeyBackup                  = (...args) => ce().exportKeyBackup?.(...args)
export const importKeyBackup                  = (...args) => ce().importKeyBackup?.(...args)
export const hasSession                       = (...args) => ce().hasSession?.(...args)
export const initOutboundSession              = (...args) => ce().initOutboundSession?.(...args)
export const fetchParticipantBundles          = (...args) => ce().fetchParticipantBundles?.(...args)
export const clearKeystore                    = (...args) => ce().clearKeystore?.(...args)

export default ce()
