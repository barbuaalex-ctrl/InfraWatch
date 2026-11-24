function isDeviceAgent(target) {
  return ['windows-agent', 'linux-agent'].includes(target?.kind);
}

module.exports = { isDeviceAgent };
