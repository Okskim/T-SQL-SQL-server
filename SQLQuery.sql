--процедура, с входными данными
--с выгрузкой отчета по объему заказываемых продуктов с учетом требуемого периода(для расчета использован объем-количество, предполагаемый изначально на 5 дней), 
--с применением коэффициентов (прироста и убывания)
--выгрузка данных производится во временную таблицу
CREATE OR ALTER PROCEDURE PercentDecreaseGrowth 
	@Period int = 0,
	@Coefficient_Growth decimal(5,3) = 0,
	@Coefficient_Decrease decimal(5,3) = 0	
AS
BEGIN
	SET NOCOUNT ON;
	DROP TABLE IF EXISTS Tempdb_Table;	
	SELECT Products.ProductID, ProductName, CategoryName, Products.UnitPrice, QUANTITY, Period=@Period, (convert(decimal(5,1),Growth)) AS Growth,(convert(decimal(5,1),Decrease)) AS Decrease, CompanyName 
	INTO Tempdb_Table
	FROM Products
	JOIN (SELECT ProductID, (convert(decimal(5,1),Quantity)) AS QUANTITY, (((convert(decimal(5,1),Quantity))/5)*@Period)+(((convert(decimal(5,1),Quantity))/5)*@Period*@Coefficient_Growth) AS Growth, ((((convert(decimal(5,1),Quantity))/5)*@Period)-(((convert(decimal(5,1),Quantity))/5)*@Period*@Coefficient_Decrease)) AS Decrease
		  FROM [Order Details]		  		  
		 ) AS Q ON Q.ProductID=Products.ProductID 
	JOIN Suppliers ON Suppliers.SupplierID=Products.SupplierID
	JOIN Categories ON Categories.CategoryID=Products.CategoryID;			
END;
GO

EXEC PercentDecreaseGrowth @Period=10, @Coefficient_Growth=0.10, @Coefficient_Decrease=0.10;

SELECT * FROM Tempdb_Table;
GO

--------------------------------------------------------------------------
--создание индекса по сотруднику
CREATE NONCLUSTERED INDEX idx_EmloyeeS_EmloyeeID ON Employees (EmployeeID);
GO
--процедура, с применением дополнительного входного параметра - ID по сотруднику
--с применением изоляции (по индексу)

CREATE OR ALTER PROCEDURE PercentDecreaseGrowth 
	@Period int = 0,
	@Coefficient_Growth decimal(5,3) = 0,
	@Coefficient_Decrease decimal(5,3) = 0,
	@Emloyeeid int
AS
BEGIN
	SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
	BEGIN TRANSACTION;	
	SET NOCOUNT ON;
	DROP TABLE IF EXISTS Tempdb_Table;	
	SELECT DISTINCT ProductName, CategoryName, Products.UnitPrice, Period=@Period, QUANTITY, (convert(decimal(5,1),Growth)) AS Growth,(convert(decimal(5,1),Decrease)) AS Decrease, CompanyName, EmployeeID
	INTO Tempdb_Table
	FROM Products	
	JOIN (SELECT EmployeeID, ProductID, (convert(decimal(5,1),Quantity)) AS QUANTITY, (((convert(decimal(5,1),Quantity))/5)*@Period)+(((convert(decimal(5,1),Quantity))/5)*@Period*@Coefficient_Growth) AS Growth, ((((convert(decimal(5,1),Quantity))/5)*@Period)-(((convert(decimal(5,1),Quantity))/5)*@Period*@Coefficient_Decrease)) AS Decrease		  
		  FROM [Order Details]
		  JOIN Orders ON Orders.OrderID=[Order Details].OrderID
		 ) AS Q ON Q.ProductID=Products.ProductID 
	JOIN Suppliers ON Suppliers.SupplierID=Products.SupplierID
	JOIN Categories ON Categories.CategoryID=Products.CategoryID
	WHERE EmployeeID = @Emloyeeid	
	COMMIT TRANSACTION;
END;
GO

EXEC PercentDecreaseGrowth @Period=10, @Coefficient_Growth=0.10, @Coefficient_Decrease=0.10, @Emloyeeid=4;

SELECT * FROM Tempdb_Table;
GO
---------------------------------------------------------------------------------------------
--сравниваем Quantity с AVG(Quantity) по каждому ProductID , выводим оконной функцией  

DECLARE @Period int=10,
@Growth decimal(5,3) = 0.1,
@Decrease decimal(5,3)=0.1;

WITH Filtered AS
(					
SELECT Products.ProductID, ProductName, Period=@Period, Quantity, AVG(Quantity) OVER (PARTITION BY Products.ProductID) AS AVGQUANTITY, (convert(decimal(5,1),Growth)) AS Growth,(convert(decimal(5,1),Decrease)) AS Decrease	
FROM Products
JOIN (SELECT ProductID, Quantity, (((convert(decimal(5,1),Quantity))/5)*@Period)+(((convert(decimal(5,1),Quantity))/5)*@Period*@Growth) AS Growth,((((convert(decimal(5,1),Quantity))/5)*@Period)-(((convert(decimal(5,1),Quantity))/5)*@Period*@Decrease)) AS Decrease						
	  FROM [Order Details]	  	
	  GROUP BY ProductID, Quantity
	) AS Q ON Q.ProductID=Products.ProductID	
)

SELECT * FROM Filtered;
GO
---------------------------------------------------------------------------------------
--ранжируем ProductID и выводим во внешнем запросе с помощью оконной функции по нарастающей итог AVG(Quantity) по ProductID (ROWID)

DECLARE @Period int=10,
@Growth decimal(5,3) = 0.1,
@Decrease decimal(5,3)=0.1;

WITH Filtered AS
(					
SELECT ROWID, Products.ProductID, ProductName, Period=@Period, Quantity, AVG(Quantity) OVER (ORDER BY ROWID) AS AVGQUANTITY, (convert(decimal(5,1),Growth)) AS Growth,(convert(decimal(5,1),Decrease)) AS Decrease	
FROM Products
JOIN (SELECT ProductID, Quantity,(((convert(decimal(5,1),Quantity))/5)*@Period)+(((convert(decimal(5,1),Quantity))/5)*@Period*@Growth) AS Growth,((((convert(decimal(5,1),Quantity))/5)*@Period)-(((convert(decimal(5,1),Quantity))/5)*@Period*@Decrease)) AS Decrease,
      row_number() OVER (ORDER BY ProductID) AS ROWID
	  FROM [Order Details]	  
	  GROUP BY ProductID, Quantity	  
	) AS Q ON Q.ProductID=Products.ProductID
)

SELECT * FROM Filtered;
GO
---------------------------------------------------------------------------------------------
--ранжируем Growth, выводим значения Rank_Growth = 2 (где Growth (количество с учетом прироста) > 80)

DECLARE @Period int=10,
@Growth decimal(5,3) = 0.1;

WITH Filtered AS
(					
SELECT Products.ProductID, ProductName, Period=@Period, Quantity,(convert(decimal(5,1),Growth)) AS Growth,
	   DENSE_RANK() OVER(
	                     ORDER BY
						      CASE
								 WHEN Growth < 80 THEN 1
								 WHEN Growth > 80 THEN 2
								 ELSE 0
							  END
						 ) AS Rank_Growth
FROM Products
JOIN (SELECT ProductID, Quantity, (((convert(decimal(5,1),Quantity))/5)*@Period)+(((convert(decimal(5,1),Quantity))/5)*@Period*@Growth) AS Growth					
	  FROM [Order Details]	  	
	  GROUP BY ProductID, Quantity	  
	) AS Q ON Q.ProductID=Products.ProductID	
)

SELECT * FROM Filtered WHERE Rank_Growth = 2 ORDER BY ProductID;
GO
--------------------------------------------------------------------------------------
--создаем триггер, кторый сработает при операциях INSERT, UPDATE над таблицей Products, 
--произойдет автоматическое обновление цены на определенные категории продуктов

CREATE TRIGGER SetPrice
ON Products
AFTER INSERT, UPDATE
AS
UPDATE Products
SET UnitPrice = UnitPrice*0.10+UnitPrice
WHERE CategoryID IN(1,2,3)


