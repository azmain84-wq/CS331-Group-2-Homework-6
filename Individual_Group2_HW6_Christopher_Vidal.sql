-- I want to know all the persons that are customers
SELECT                      -- return matching first/last name pairs
  person.FirstName,         -- person’s given name
  person.LastName           -- person’s family name
FROM Person.Person AS person -- source set A: everyone in the Person.Person table
INTERSECT                   -- set operator: returns rows that appear in BOTH sets (duplicated)
SELECT
  sp.FirstName,             -- customer’s given name in the view
  sp.LastName               -- customer’s family name in the view
FROM Sales.vIndividualCustomer AS sp; -- source set B: individuals who are customers (view)



-- I want to know all the persons that work in the Sales department (current)
SELECT
  p.FirstName,              -- candidate first name from the full Person list
  p.LastName                -- candidate last name
FROM Person.Person AS p     -- set A: all people recorded
INTERSECT                   -- keep only those that also appear in the “current Sales” result below
SELECT
  p2.FirstName,             -- first name for employees matched to Sales dept
  p2.LastName               -- last name for employees matched to Sales dept
FROM HumanResources.EmployeeDepartmentHistory AS edh -- employment history by department
JOIN HumanResources.Department AS d
  ON d.DepartmentID = edh.DepartmentID  -- resolve department name
JOIN Person.Person AS p2
  ON p2.BusinessEntityID = edh.BusinessEntityID -- map assignment to the person’s name
WHERE d.Name = 'Sales'                   -- filter to the Sales department
  AND edh.EndDate IS NULL;               -- “current” assignment (no end date)

-----------------------------------------------------------------------------------------------

-- I want to know all the persons that have both an email and a phone number
WITH HasEmail AS (                        -- CTE #1: people who have at least one email
  SELECT
    p.FirstName,                          -- first name from Person
    p.LastName                            -- last name from Person
  FROM Person.EmailAddress AS ea          -- email rows
  JOIN Person.Person AS p
    ON p.BusinessEntityID = ea.BusinessEntityID -- link email row to person
),
HasPhone AS (                             -- CTE #2: people who have at least one phone
  SELECT
    p.FirstName,                          -- first name from Person
    p.LastName                            -- last name from Person
  FROM Person.PersonPhone AS ph           -- phone rows
  JOIN Person.Person AS p
    ON p.BusinessEntityID = ph.BusinessEntityID -- link phone row to person
)
SELECT FirstName, LastName FROM HasEmail  -- set A: with email
INTERSECT                                 -- keep only those also in set B
SELECT FirstName, LastName FROM HasPhone; -- set B: with phone

-- Tip: INTERSECT de-duplicates automatically.
-----------------------------------------------------------------------------------------------

-- I want to know all the persons that are individual customers or purchasing employees (unique list)
WITH IndividualCustomers AS (             -- CTE #1: people who are customers (individuals)
  SELECT DISTINCT                         -- dedupe inside CTE (optional because UNION also dedupes)
    p.FirstName,
    p.LastName
  FROM Sales.Customer AS c
  JOIN Person.Person AS p
    ON p.BusinessEntityID = c.PersonID    -- PersonID populated only for individual customers
  WHERE c.PersonID IS NOT NULL
),
PurchasingEmployees AS (                  -- CTE #2: people who appear on purchase orders as employees
  SELECT DISTINCT
    p.FirstName,
    p.LastName
  FROM Purchasing.PurchaseOrderHeader AS poh
  JOIN HumanResources.Employee AS e
    ON e.BusinessEntityID = poh.EmployeeID -- employee tied to the PO
  JOIN Person.Person AS p
    ON p.BusinessEntityID = e.BusinessEntityID -- resolve name
)
SELECT FirstName, LastName FROM IndividualCustomers -- set A
UNION                                            -- UNION = A ∪ B, removes duplicates
SELECT FirstName, LastName FROM PurchasingEmployees; -- set B

-----------------------------------------------------------------------------------------------

-- I want to know all the persons that have both a Home phone and a Cell phone
;WITH HomePhones AS (                       -- CTE #1: people with at least one Home phone
  SELECT
    p.FirstName,
    p.LastName
  FROM Person.PersonPhone AS ph
  JOIN Person.PhoneNumberType AS t
    ON t.PhoneNumberTypeID = ph.PhoneNumberTypeID -- resolve phone type
  JOIN Person.Person AS p
    ON p.BusinessEntityID = ph.BusinessEntityID   -- map phone to person
  WHERE t.Name = 'Home'                           -- only “Home” numbers
),
CellPhones AS (                          -- CTE #2: people with at least one Cell phone
  SELECT
    p.FirstName,
    p.LastName
  FROM Person.PersonPhone AS ph
  JOIN Person.PhoneNumberType AS t
    ON t.PhoneNumberTypeID = ph.PhoneNumberTypeID
  JOIN Person.Person AS p
    ON p.BusinessEntityID = ph.BusinessEntityID
  WHERE t.Name = 'Cell'                          -- only “Cell” numbers
)
SELECT FirstName, LastName FROM HomePhones       -- set A
INTERSECT                                        -- intersection (A ∩ B)
SELECT FirstName, LastName FROM CellPhones;      -- set B

-----------------------------------------------------------------------------------------------

-- I want to know all the persons that have an email or a phone number
;WITH HasEmail AS (                       -- CTE #1: people with email
  SELECT
    p.FirstName,
    p.LastName
  FROM Person.EmailAddress AS ea
  JOIN Person.Person AS p
    ON p.BusinessEntityID = ea.BusinessEntityID
),
HasPhone AS (                            -- CTE #2: people with phone
  SELECT
    p.FirstName,
    p.LastName
  FROM Person.PersonPhone AS ph
  JOIN Person.Person AS p
    ON p.BusinessEntityID = ph.BusinessEntityID
)
SELECT FirstName, LastName FROM HasEmail  -- set A
UNION                                     -- UNION (distinct) across A and B
SELECT FirstName, LastName FROM HasPhone; -- set B

-- If you want to keep duplicates (e.g., for counting), use UNION ALL instead of UNION.
-----------------------------------------------------------------------------------------------

-- I want to know all the persons that currently work in Sales or Marketing
;WITH SalesDept AS (                      -- CTE #1: current Sales employees
  SELECT
    p.FirstName,
    p.LastName
  FROM HumanResources.EmployeeDepartmentHistory AS edh
  JOIN HumanResources.Department AS d
    ON d.DepartmentID = edh.DepartmentID       -- get department name
  JOIN Person.Person AS p
    ON p.BusinessEntityID = edh.BusinessEntityID -- map to person
  WHERE d.Name = 'Sales'
    AND edh.EndDate IS NULL                    -- current assignment only
),
MarketingDept AS (                       -- CTE #2: current Marketing employees
  SELECT
    p.FirstName,
    p.LastName
  FROM HumanResources.EmployeeDepartmentHistory AS edh
  JOIN HumanResources.Department AS d
    ON d.DepartmentID = edh.DepartmentID
  JOIN Person.Person AS p
    ON p.BusinessEntityID = edh.BusinessEntityID
  WHERE d.Name = 'Marketing'
    AND edh.EndDate IS NULL
)
SELECT FirstName, LastName FROM SalesDept   -- set A
UNION                                       -- union distinct with set B
SELECT FirstName, LastName FROM MarketingDept; -- set B

-----------------------------------------------------------------------------------------------

-- I want to know all the persons that have a US address or a Canada address
;WITH USPersons AS (                       -- CTE #1: people linked to at least one US address
  SELECT DISTINCT
    p.FirstName,
    p.LastName
  FROM Person.BusinessEntityAddress AS bea
  JOIN Person.Address AS a
    ON a.AddressID = bea.AddressID             -- resolve address
  JOIN Person.StateProvince AS sp
    ON sp.StateProvinceID = a.StateProvinceID  -- resolve country via state/province
  JOIN Person.Person AS p
    ON p.BusinessEntityID = bea.BusinessEntityID -- map address to person
  WHERE sp.CountryRegionCode = 'US'
),
CAPersons AS (                           -- CTE #2: people linked to at least one Canada address
  SELECT DISTINCT
    p.FirstName,
    p.LastName
  FROM Person.BusinessEntityAddress AS bea
  JOIN Person.Address AS a
    ON a.AddressID = bea.AddressID
  JOIN Person.StateProvince AS sp
    ON sp.StateProvinceID = a.StateProvinceID
  JOIN Person.Person AS p
    ON p.BusinessEntityID = bea.BusinessEntityID
  WHERE sp.CountryRegionCode = 'CA'
)
SELECT FirstName, LastName FROM USPersons -- set A (US)
UNION                                     -- union distinct with set B (CA)
SELECT FirstName, LastName FROM CAPersons;

-----------------------------------------------------------------------------------------------

-- I want to know all the persons that have an email but no phone number
;WITH HasEmail AS (                       -- CTE #1: people with email
  SELECT
    p.FirstName,
    p.LastName
  FROM Person.EmailAddress AS ea
  JOIN Person.Person AS p
    ON p.BusinessEntityID = ea.BusinessEntityID
),
HasPhone AS (                            -- CTE #2: people with phone
  SELECT
    p.FirstName,
    p.LastName
  FROM Person.PersonPhone AS ph
  JOIN Person.Person AS p
    ON p.BusinessEntityID = ph.BusinessEntityID
)
SELECT FirstName, LastName FROM HasEmail  -- set A
EXCEPT                                    -- A \ B (in A but not in B), distinct output
SELECT FirstName, LastName FROM HasPhone; -- set B

-----------------------------------------------------------------------------------------------

-- I want to know all the persons that are employees but not currently in the Sales department
;WITH Employees AS (                      -- CTE #1: all employees
  SELECT
    p.FirstName,
    p.LastName
  FROM HumanResources.Employee AS e
  JOIN Person.Person AS p
    ON p.BusinessEntityID = e.BusinessEntityID
),
CurrentSalesDept AS (                     -- CTE #2: employees currently in Sales
  SELECT
    p.FirstName,
    p.LastName
  FROM HumanResources.EmployeeDepartmentHistory AS edh
  JOIN HumanResources.Department AS d
    ON d.DepartmentID = edh.DepartmentID
  JOIN Person.Person AS p
    ON p.BusinessEntityID = edh.BusinessEntityID
  WHERE d.Name = 'Sales'
    AND edh.EndDate IS NULL
)
SELECT FirstName, LastName FROM Employees  -- set A: all employees
EXCEPT                                     -- employees EXCEPT current Sales
SELECT FirstName, LastName FROM CurrentSalesDept; -- set B: current Sales only





