pragma solidity ^0.4.18;



// For the sake of simplicity lets assume EUR is a ERC20 token 
// Also lets assume we can 100% trust the exchange rate oracle 
contract PayrollInterface { 
/* OWNER ONLY */ 
function addEmployee(address accountAddress, address[] allowedTokens, uint256 initialYearlyEURSalary) external; 
function setEmployeeSalary(uint256 employeeId, uint256 yearlyEURSalary) external; 
function removeEmployee(uint256 employeeId) external;
function addFunds() payable external; 
function escapeHatch() external; 
// function addTokenFunds()? // Use approveAndCall or ERC223 tokenFallback 

function getEmployeeCount() external constant returns (uint256); 
function getEmployee(uint256 employeeId) external constant returns (address employee, address[] allowedTokens, uint256 yearlyEURSalary); // Return all important info too 
function calculatePayrollBurnrate() external constant returns (uint256); // Monthly EUR amount spent in salaries 
function calculatePayrollRunway() external constant returns (uint256); // Days until the contract can run out of funds 

/* EMPLOYEE ONLY */ 
function determineAllocation(address[] tokens, uint256[] distribution) external; // only callable once every 6 months 
function payday() external; // only callable once a month 

/* ORACLE ONLY */ 
function setExchangeRate(address token, uint256 EURExchangeRate) external; // uses decimals from token 
}

