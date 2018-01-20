pragma solidity ^0.4.18;

import "./PayrollInterface.sol";
import "./Ownable.sol";

contract Payroll is PayrollInterface, Ownable {
    
    // NOTE
    // Most functions on PayrollInterface are marked as public. I'd prefer to use external to save gas since we're not making internal calls.

    struct Employee {
      address account;
      address[] tokens;
      uint256 yearlyEURSalary;
    }

    Employee[] public employees;
    mapping(address => uint256) employeeCatalog;
    uint256 public employeeCount;
    uint256 public lastIdx;

    event NewEmployee(uint256 idx, address account, address[] allowedTokens, uint256 yearlyEURSalary);
    event EmployeeSalaryChange(uint256 idx, uint256 oldYearlyEURSalary,  uint256 newYearlyEURSalary);
    event EmployeeRemoved(uint256 employeeId);
    event LogScapeHatch();
    
    
    modifier employeeExists(uint256 employeeId) {
        require(employees[employeeId].account != address(0x0));
        _;
    }
    
    // NOTE: I'd suggest to modify the interdace in order for this function to return the employee id
    //       (you could access the ID with the NewEmployee event, tho)
    function addEmployee(address accountAddress, address[] allowedTokens, uint256 initialYearlyEURSalary) 
        onlyOwner 
        public {
        
        require(accountAddress != address(0x0));
        require(employeeCatalog[accountAddress] == 0);
            
        // TODO research what is allowedTokens going to be used for?
        lastIdx = employees.push(Employee(accountAddress, allowedTokens, initialYearlyEURSalary) );
        employeeCatalog[accountAddress] = lastIdx;
        employeeCount++;
        
        NewEmployee(lastIdx, accountAddress, allowedTokens, initialYearlyEURSalary);
    }
    
    function setEmployeeSalary(uint256 employeeId, uint256 yearlyEURSalary) 
        onlyOwner 
        employeeExists(employeeId)
        public {
        
        uint256 oldYearlyEURSalary = employees[employeeId].yearlyEURSalary;
        
        require(yearlyEURSalary != oldYearlyEURSalary);
        
        employees[employeeId].yearlyEURSalary = yearlyEURSalary;
        EmployeeSalaryChange(employeeId, oldYearlyEURSalary,  yearlyEURSalary);
    }

    function removeEmployee(uint256 employeeId)
        onlyOwner 
        employeeExists(employeeId)
        public {
            
        delete employeeCatalog[employees[employeeId].account];
        delete employees[employeeId];
        employeeCount--;
        
        EmployeeRemoved(employeeId);
    }
    
    function addFunds() 
        payable 
        onlyOwner 
        public {
        // nothing to see here ...
    }
    
    // TODO research about the functionality. Should this be a way to kill the contract?
    //      if that's the case, should I do something with the tokens?
    function scapeHatch() 
        onlyOwner 
        public {
        LogScapeHatch();
        selfdestruct(owner);
    }
    
    function getEmployeeCount() 
        constant 
        public
        returns (uint256) {
        return employeeCount;
    }
    
    // NOTE: this is returning an address... so, to return all important info I needed to add an additional function. 
    //       I could do it in this function but I'm not sure I'm allowed to change the interface definition in this 
    //       code challenge
    function getEmployee(uint256 employeeId) 
        constant 
        public returns (address employee){
        
        return employees[employeeId].account;
    }
    
    function getEmployeeInfo(uint256 employeeId)
        constant
        public returns(address employee, address[] allowedTokens, uint256 yearlyEURSalary) {
            
        Employee memory e = employees[employeeId];
        return (e.account, e.tokens, e.yearlyEURSalary);
    }
    
    function calculatePayrollBurnrate() 
        constant 
        public 
        returns (uint256) {
        // Hopefully the number of employees is low enough to not cause an out of gas error
        uint256 eurAmount = 0;
        address emptyAddress = address(0x0);
        
        for(uint256 i = 0; i < lastIdx - 1; i++){
            if(employees[i].account != emptyAddress)
                eurAmount += employees[i].yearlyEURSalary; // TODO safemath
        }
        
        return eurAmount / 12;
    } 
    
    // TODO
    function calculatePayrollRunway() constant returns (uint256); // Days until the contract can run out of funds 

    
    
}