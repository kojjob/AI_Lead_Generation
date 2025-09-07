// Manual Test Script for Stimulus Controllers
// Run this in the browser console on the sign-in or sign-up pages

console.log("=== Starting Stimulus Controller Tests ===");

// Test 1: Check if Stimulus is loaded
if (typeof Stimulus !== 'undefined') {
  console.log("✅ Stimulus is loaded");
  const controllers = Stimulus.router.modules.map(m => m.identifier);
  console.log("Registered controllers:", controllers);
} else {
  console.log("❌ Stimulus is NOT loaded");
}

// Test 2: Password Toggle
console.log("\n--- Testing Password Toggle ---");
const toggleBtn = document.querySelector('[data-action*="password-toggle#toggle"]');
const passwordInput = document.querySelector('[data-password-toggle-target="input"]');

if (toggleBtn && passwordInput) {
  const initialType = passwordInput.type;
  console.log("Initial password field type:", initialType);
  
  // Simulate click
  toggleBtn.click();
  console.log("After toggle:", passwordInput.type);
  
  if (passwordInput.type !== initialType) {
    console.log("✅ Password toggle is working!");
  } else {
    console.log("❌ Password toggle is NOT working");
  }
  
  // Toggle back
  toggleBtn.click();
} else {
  console.log("❌ Password toggle elements not found");
}

// Test 3: Form Validation
console.log("\n--- Testing Form Validation ---");
const emailField = document.querySelector('[data-form-validation-target="email"]');

if (emailField) {
  // Test invalid email
  emailField.value = "invalid-email";
  emailField.dispatchEvent(new Event('input', { bubbles: true }));
  emailField.dispatchEvent(new Event('blur', { bubbles: true }));
  
  setTimeout(() => {
    if (emailField.classList.contains('border-red-500')) {
      console.log("✅ Email validation shows error for invalid email");
    }
    
    // Test valid email
    emailField.value = "test@example.com";
    emailField.dispatchEvent(new Event('input', { bubbles: true }));
    emailField.dispatchEvent(new Event('blur', { bubbles: true }));
    
    setTimeout(() => {
      if (emailField.classList.contains('border-green-500')) {
        console.log("✅ Email validation shows success for valid email");
      }
    }, 100);
  }, 100);
}

console.log("\n=== Tests Complete ===");
