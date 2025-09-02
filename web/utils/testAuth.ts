// Utility functions for testing authentication flow

export const testLogin = () => {
  // Simulate a login with dummy data
  const dummyToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkFkbWluIFRlc3QiLCJpYXQiOjE1MTYyMzkwMjJ9.test-token-for-debugging';
  const dummyUser = {
    id: 1,
    email: 'admin@gmail.com',
    role: 'admin',
    first_name: 'Admin',
    last_name: 'Test'
  };

  // Store in all locations
  localStorage.setItem('admin_token', dummyToken);
  sessionStorage.setItem('admin_token', dummyToken);
  
  console.log('Test login completed with dummy data');
  return { token: dummyToken, user: dummyUser };
};

export const clearAllAuth = () => {
  localStorage.removeItem('admin_token');
  sessionStorage.removeItem('admin_token');
  // Clear cookies
  document.cookie = 'admin_token=; expires=Thu, 01 Jan 1970 00:00:00 UTC; path=/;';
  
  console.log('All auth data cleared');
};

export const checkAllStorages = () => {
  const results = {
    localStorage: localStorage.getItem('admin_token'),
    sessionStorage: sessionStorage.getItem('admin_token'),
    cookies: document.cookie.includes('admin_token')
  };
  
  console.log('Storage check:', results);
  return results;
};