pragma solidity ^0.4.18;

import "./PayrollInterface.sol";
import "./Ownable.sol";
import "./Oracleizable.sol";
import "./DetailedERC20.sol";
import "./DateTimeAPI.sol";

contract Payroll is PayrollInterface, Ownable, Oracleizable {
    
    // NOTE
    // Most functions on PayrollInterface are marked as public. I'd prefer to use external to save gas since we're not making internal calls.
    
    function Payroll(address _oracle)
        public
        Ownable()
        Oracleizable(_oracle){
        // Nothing to see here ...
    }

    struct Employee {
      address account;
      
      address[] tokens;
      uint256[] distribution;
      
      uint256 yearlyEURSalary;
      
      uint lastAllocationTimestamp;
      uint lastPayday;
    }

    Employee[] public employees;
    mapping(address => uint256) employeeCatalog;
    uint256 public employeeCount;
    uint256 public lastIdx;
    
    uint256 totalYearlyEmployeeEURSalary;
    
    address[] validTokenList;
    mapping(address => bool) validTokenCatalog;
    mapping(address => uint256) validTokensRate;
  

    event NewEmployee(uint256 idx, address account, address[] allowedTokens, uint256 yearlyEURSalary);
    event EmployeeSalaryChange(uint256 idx, uint256 oldYearlyEURSalary,  uint256 newYearlyEURSalary);
    event EmployeeRemoved(uint256 employeeId);
    event LogScapeHatch();
    
    event NewValidTokensSet(address token, bool allowed);
    event NewTokenAllowanceSet(uint256 employeeId, address[] tokenList);
    event AllocationSet(address employee, address[] tokens, uint256[] distribution);
    
    modifier employeeExists(uint256 employeeId) {
        require(employees[employeeId].account != address(0x0));
        _;
    }
    
    // NOTE: I'd suggest to modify the interface in order for this function to return the employee id
    //       (you could access the ID with the NewEmployee event, tho)
    function addEmployee(address accountAddress, address[] allowedTokens, uint256 initialYearlyEURSalary) 
        onlyOwner 
        public {
        
        require(accountAddress != address(0x0));
        require(employeeCatalog[accountAddress] == 0);
            
        for(uint256 i = 0; i < allowedTokens.length; i++){
            // Assume that a token is allowed if it's in allowedMapping
            if(!validTokenCatalog[allowedTokens[i]]){
                revert();
            }
        }
        
        uint256[] memory emptyDistribution = new uint256[](1);
        
        lastIdx = employees.push(Employee(accountAddress, allowedTokens, emptyDistribution, initialYearlyEURSalary, 0, 0) );
        employeeCatalog[accountAddress] = lastIdx;
        employeeCount++;
        
        // NOTE To save gas, instead of calculating the monthly salary in calculatePayrollBurnrate
        //      I simply update this variable when there's a change related to salaries
        totalYearlyEmployeeEURSalary += initialYearlyEURSalary;
        
        NewEmployee(lastIdx, accountAddress, allowedTokens, initialYearlyEURSalary);
    }
    
    function isTokenAllowed(address[] employeeTokens, address token)
        public
        constant
        returns(bool) {
        for(uint256 i = 0; i < employeeTokens.length; i++){
            if(!isTokenValid(employeeTokens[i])) return false;
        }
       return true;
    }
    
    function isTokenValid(address token)
        public
        constant
        returns(bool) {
        return validTokenCatalog[token];
    }
    
    
       
    function updateContractValidTokens(address token, bool allowed)
        public
        onlyOwner
    {
        NewValidTokensSet(token, allowed);
        
        validTokenCatalog[token] = allowed;
        validTokenList.push(token);
    }
    
    
    function updateTokenAllowance(uint256 employeeId, address[] tokenList)
        public
        onlyOwner
        employeeExists(employeeId)
    {
        employees[employeeId].tokens = tokenList;
        NewTokenAllowanceSet(employeeId, tokenList);
    }
    
    function setEmployeeSalary(uint256 employeeId, uint256 yearlyEURSalary) 
        onlyOwner 
        employeeExists(employeeId)
        public {
        
        uint256 oldYearlyEURSalary = employees[employeeId].yearlyEURSalary;
        
        require(yearlyEURSalary != oldYearlyEURSalary);
        
        employees[employeeId].yearlyEURSalary = yearlyEURSalary;
        
        // Removing the old salary and adding new
        totalYearlyEmployeeEURSalary -= oldYearlyEURSalary;
        totalYearlyEmployeeEURSalary += yearlyEURSalary;
        
        EmployeeSalaryChange(employeeId, oldYearlyEURSalary,  yearlyEURSalary);
    }

    function removeEmployee(uint256 employeeId)
        onlyOwner 
        employeeExists(employeeId)
        public {
            
        totalYearlyEmployeeEURSalary -= employees[employeeId].yearlyEURSalary;
            
        delete employeeCatalog[employees[employeeId].account];
        delete employees[employeeId];
        employeeCount--;
        
        EmployeeRemoved(employeeId);
    }
    
    function addFunds() 
        payable 
        onlyOwner 
        public {
        // TODO ask why are we accepting eth if the payment is in tokens.
    }
    
    // Is this a typo?
    function scapeHatch() 
        onlyOwner 
        public {
        
        LogScapeHatch();
            
        // Send tokens to owner;
        for(uint256 i = 0; i < validTokenList.length; i++){
            DetailedERC20 erc20Token = DetailedERC20(validTokenList[i]);
            erc20Token.transfer(owner, erc20Token.balanceOf(this));    
        }
        
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
       
        return totalYearlyEmployeeEURSalary / 12;
    } 
    
    // TODO
    function calculatePayrollRunway() 
        constant 
        public
        returns (uint256){
        // Days until the contract can run out of funds 
            
            
            
    }
    
    modifier onlyEmployees() {
        require(employeeCatalog[msg.sender] > 0);
        _;
    }
    
    // only callable once every 6 months 
    function determineAllocation(address[] tokens, uint256[] distribution)
        onlyEmployees
        public
    {
        // distribution and tokens should be equal length
        require(distribution.length == tokens.length);

        Employee storage e = employees[employeeCatalog[msg.sender]];
        
        require(now > addMonths(e.lastAllocationTimestamp, 6));
        
        uint256 i;
        
        // Check that 'tokens' is in the allowed token list 
        for(i = 0; i < tokens.length; i++){
            if(!isTokenAllowed(e.tokens, tokens[i])) revert();
        }
        
        uint256 distTotal = 0;
        for(i = 0; i < distribution.length; i++){
            distTotal += distribution[i];
        }
        
        // Distribution is percentage based, so check that distribution is equals to 100
        if(distTotal < 100) revert();
        
        e.lastAllocationTimestamp = now;
        e.distribution = distribution;
        
        AllocationSet(msg.sender, tokens, distribution);
    } 
    
    
    function payday()
        onlyEmployees
        public
    {
        // only callable once a month 
        Employee storage e = employees[employeeCatalog[msg.sender]];
        require(now > addMonths(e.lastPayday, 6));
        
        e.lastPayday = now;
        
        // TODO check if employee has distribution set
        
        // TODO calculate distribution
        
    }
    
    function addMonths(uint ts, uint8 months)
        constant
        internal
        returns(uint)
    {
        assert(months <= 12);
            
        DateTimeAPI dt = DateTimeAPI(address(0x1a6184CD4C5Bea62B0116de7962EE7315B7bcBce));
        uint16 y = dt.getYear(ts);
        uint8 m = dt.getMonth(ts) + months;
        
        if(m > 12){
            y++;
            m -= 12;
        } 

        return dt.toTimestamp(y, m,  dt.getDay(ts), dt.getHour(ts), dt.getMinute(ts), dt.getSecond(ts));
    }
    
    function setExchangeRate(address token, uint256 EURExchangeRate)
        public 
        onlyOracle
    {
        
        DetailedERC20 erc20token = DetailedERC20(token);
        validTokensRate[token] =  EURExchangeRate * erc20token.decimals();
    }
    
}