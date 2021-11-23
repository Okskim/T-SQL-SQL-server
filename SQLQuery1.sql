--процедура, с входными данными,
--с выгрузкой отчета по объему заказазываемых продуктов с учетом требуемого периода(использован объем-количество, рассчитанное изначально на 5 дней), 
--с применением коэффициента (прироста, убывания)
--выгрузка данных во временную таблицу
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


