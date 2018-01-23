pragma solidity ^0.4.18;

import "./PayrollInterface.sol";
import "./Ownable.sol";
import "./Pausable.sol";
import "./Oracleizable.sol";
import "./DetailedERC20.sol";
import "./DateTimeAPI.sol";

contract Payroll is PayrollInterface, Ownable, Oracleizable, Pausable {
    
    // NOTE
    // Most functions on PayrollInterface are marked as public. I'd prefer to use external to save gas since we're not making internal calls.
    
    /** @dev Payroll contract constructor
      * @param _oracle Oracle address that will set the exchange rate
      */
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
    
    /** @dev Modifier to check wether and employee exists
      * @param employeeId ID of the employee to verify
      */
    modifier employeeExists(uint256 employeeId) {
        require(employees[employeeId].account != address(0x0));
        _;
    }
    
    
    /** @dev Add employee. Can only be called by the owner of the contract
      * @param accountAddress Employee eth account
      * @param allowedTokens Array of the tokens addresses in which the employee will be paid
      * @param initialYearlyEURSalary Yearly salary in EUR
      */
    function addEmployee(address accountAddress, address[] allowedTokens, uint256 initialYearlyEURSalary) 
        onlyOwner 
        public {
        
        // NOTE: I'd suggest to modify the interface in order for this function to return the employee id
        //       (you could access the ID with the NewEmployee event, tho)
        
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
    

	/** @dev Check whether the selected tokens of a employee are in the allowed list of tokens
      * @param emplyeeTokens Array of token address
      * @param allowedTokens Array of the tokens addresses in which the employee will be paid
      * @param initialYearlyEURSalary Yearly salary in EUR
      * @return Token allowed or not
      */
    function areTokensAllowed(address[] employeeTokens)
        public
        constant
        returns(bool) {
        for(uint256 i = 0; i < employeeTokens.length; i++){
            if(!isTokenValid(employeeTokens[i])) return false;
        }
       return true;
    }
    
    
	/** @dev Check if the token is in the list of tokens handled by the contract
      * @param token Address of token to be verified
      * @param allowedTokens Array of the tokens addresses in which the employee will be paid
      * @param initialYearlyEURSalary Yearly salary in EUR
      * @return Token valid or not
      */
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
        // TODO ask why are we accepting eth if the payment is in tokens.?
    }
    
    
    // Is this a typo?
    function scapeHatch() 
        onlyOwner 
        onlyPaused
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
    
    
    /** @dev Monthly EUR amount spent in salaries
      */
    function calculatePayrollBurnrate() 
        constant 
        public 
        returns (uint256) {
       
        return totalYearlyEmployeeEURSalary / 12;
    } 
    
    
    // TODO test
    function calculatePayrollRunway() 
        constant 
        public
        returns (uint256){
        // Days until the contract can run out of funds   
        
        uint256 i;
        uint256 j;
        uint256 k;
        
        uint256[] memory contractBalanceEUR = new uint256[](validTokenList.length);
        uint256[] memory amountNeededEUR = new uint256[](validTokenList.length);
        
        
        // O(N) operations - improve.
        
        for (i = 0; i < validTokenList.length; i++){
            DetailedERC20 currentToken = DetailedERC20(validTokenList[i]);
            // Get balances for tokens in EUR
            contractBalanceEUR[i] = currentToken.balanceOf(this) / validTokensRate[validTokenList[i]];
            
            // Calculate needed tokens for a year
            for(j = 0; j < employees.length; j++){
                if(employees[j].account != address(0x0)){
                    Employee storage e = employees[j];
                    // Each employee may have a different list of tokens
                    for(k = 0; k < e.tokens.length; k++){
                        if(e.tokens[k] == validTokenList[i]){
                            amountNeededEUR[i] += (e.yearlyEURSalary * e.distribution[k] / 100) / validTokensRate[e.tokens[k]];
                        }
                    }
                }
            }
        }
        
        uint256 maxDays = contractBalanceEUR[0] / amountNeededEUR[0] * 365; // Max days we can pay for first token
        for (i = 1; i < validTokenList.length; i++){
            uint256 currTokenDays = contractBalanceEUR[i] / amountNeededEUR[i] * 365;
            if(currTokenDays < maxDays){
                maxDays = currTokenDays;
            }
        }
        
        return maxDays;
    }
    
    
    /** @dev Modifier to only allow function calls if the sender is a valid employee
      */
    modifier onlyEmployees() {
        require(employeeCatalog[msg.sender] > 0);
        _;
    }
    
    
    // TODO test
    // only callable once every 6 months 
    function determineAllocation(address[] tokens, uint256[] distribution)
        onlyEmployees
        onlyUnpaused
        public
    {
        // distribution and tokens should be equal length
        require(distribution.length == tokens.length);

        Employee storage e = employees[employeeCatalog[msg.sender]];
        
        require(now > addMonths(e.lastAllocationTimestamp, 6));
        
        uint256 i;
        
        // Check that 'tokens' is in the allowed token list 
        if(!areTokensAllowed(e.tokens)) revert();

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
    
    
    // TODO test
    function payday()
        onlyEmployees
        onlyUnpaused
        public
    {
        // only callable once a month 
        Employee storage e = employees[employeeCatalog[msg.sender]];
        
        // Once a month
        require(now > addMonths(e.lastPayday, 1));
        
        // Checking that the employee has a valid distribution
        uint256 distTotal = 0;
        for(i = 0; i < e.distribution.length; i++){
            distTotal += e.distribution[i];
        }
        // Distribution is percentage based, so check that distribution is equals to 100
        if(distTotal < 100) revert();
        
        e.lastPayday = now;
        
        for (uint256 i = 0; i < e.tokens.length; i++) {
            uint256 tokenRate = validTokensRate[e.tokens[i]];
            uint256 eurProportionByToken = (e.yearlyEURSalary / 12) * e.distribution[i] / 100;
            
            uint256 eurToToken = eurProportionByToken / tokenRate;            
            
            DetailedERC20 erc20token = DetailedERC20(e.tokens[i]);
            erc20token.transfer(msg.sender, eurToToken);
        }
    }
    
    
    /** @dev Calculate date in N months
      * @param ts Input timestamp
      * @param months Number of months to add < 12
      * @return New timestamp
      */
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
    
    
    /** @dev Set Exchange Rate for token. Only Oracle may call this function
      * @param token Token that will have a exchange rate set
      * @param EURExchangeRate Exchange Rate: 1 EUR -> N Tokens
      */
    function setExchangeRate(address token, uint256 EURExchangeRate)
        public 
        onlyOracle
        onlyUnpaused
    {
        DetailedERC20 erc20token = DetailedERC20(token);
        validTokensRate[token] =  EURExchangeRate * erc20token.decimals();
    }
    
}