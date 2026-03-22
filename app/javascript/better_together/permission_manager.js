export default class PermissionManager {
  static queryPermission(permissionName) {
    if ("permissions" in navigator) {
      return navigator.permissions.query({ name: permissionName });
    }
    return Promise.reject(new Error("Permissions API not supported"));
  }
}