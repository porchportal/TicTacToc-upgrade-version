// Test environment setup
process.env.NODE_ENV = 'test';
process.env.PORT = '3001'; // Use different port for tests
process.env.DB_PATH = ':memory:'; // Use in-memory database for tests

// Suppress console logs during tests unless there's an error
const originalConsoleLog = console.log;
const originalConsoleError = console.error;

console.log = (...args) => {
  // Only log if it's an error or if we're in verbose mode
  if (process.env.VERBOSE_TESTS) {
    originalConsoleLog(...args);
  }
};

console.error = (...args) => {
  // Always log errors
  originalConsoleError(...args);
};

// Handle unhandled promise rejections in tests
process.on('unhandledRejection', (reason, promise) => {
  console.error('Unhandled Rejection at:', promise, 'reason:', reason);
  process.exit(1);
});

// Handle uncaught exceptions in tests
process.on('uncaughtException', (error) => {
  console.error('Uncaught Exception:', error);
  process.exit(1);
});
