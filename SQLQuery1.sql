--Задача 1
--Запросом получить всех заказчиков, которые купили товар А, но не купили товар B.
--Измерения: Клиент, Товар
--Ресурсы: количество, сумма

WITH COMPANY AS(
	SELECT Orders.OrderID, ProductID, Orders.CustomerID, CompanyName
	FROM Orders
	JOIN Customers ON Customers.CustomerID=Orders.CustomerID
	JOIN [Order Details] ON [Order Details].OrderID=Orders.OrderID	
)

SELECT DISTINCT  CompanyName, [Order Details].ProductID, ProductName, Quantity, [Order Details].UnitPrice   
FROM [Order Details]
JOIN COMPANY ON COMPANY.OrderID=[Order Details].OrderID
JOIN Products ON Products.ProductID=[Order Details].ProductID
WHERE [Order Details].ProductID = 11 AND CompanyName NOT IN (SELECT CompanyName FROM COMPANY WHERE ProductID = 42)
ORDER BY Quantity;
GO

-------------------------------------------------------------------------------------------------------
--Задача 2
--Дано: таблица значений с полями Контрагент и Сумма. 
--Напишите процедуру, которая удалит из таблицы все строки, с суммой меньше 100 рублей

--создаем временную таблицу с выборкой по сумме заказа (в качестве контрагента выступает заказчик)
SELECT CustomerID, SUM(UnitPrice) AS SUMMA
INTO Tempdb_Table
FROM [Order Details]
JOIN Orders ON Orders.OrderID=[Order Details].OrderID
GROUP BY CustomerID;
GO

CREATE OR ALTER PROCEDURE Deleterows
AS
BEGIN	
	SET NOCOUNT ON;
	DELETE FROM Tempdb_Table
	WHERE SUMMA < 100;
END;

EXEC Deleterows;
GO

SELECT *
FROM Tempdb_Table
ORDER BY SUMMA;
GO

-----------------------------------------------------------------------------------------------------
--Задача 3. 
--Дано: Справочник Сотрудников: ФИО / Дата рождения
--1) Написать запрос, который вернет всех сотрудников, у кого ДР в ближайших месяц
--2) Написать запрос, который вернет всех сотрудников, у которых в ближайший месяц будет юбилей (исполняется 30 лет, 40, 50.. и тд.)


--ДР в ближайших месяц
SELECT LastName, FirstName, BirthDate 
FROM Employees
WHERE MONTH (BirthDate) = 12;
GO

--в ближайший месяц будет юбилей (исполняется 30 лет, 40, 50.. и тд.)
SELECT LastName, FirstName, BirthDate, DATEDIFF (year, BirthDate, GETDATE()) 
FROM Employees
WHERE MONTH (BirthDate) = 01 AND  DATEDIFF (year, BirthDate, GETDATE()) IN(30,40,50,60);
GO

----------------------------------------------------------------------------------------------------
--Задача 4
--Вывести информацию о дне недели даты заказа (день недели)  
--Реализовать функцию, которая прибавляет X рабочих Дней к исходной дате.

--дни недели обозначим цифрами
SELECT OrderID, CustomerID, OrderDate, 
     CASE WHEN  DATEPART(WEEKDAY, OrderDate)= '1' THEN '1'
		  WHEN  DATEPART(WEEKDAY, OrderDate)= '2' THEN '2'
		  WHEN  DATEPART(WEEKDAY, OrderDate)= '3' THEN '3'
		  WHEN  DATEPART(WEEKDAY, OrderDate)= '4' THEN '4'
		  WHEN  DATEPART(WEEKDAY, OrderDate)= '5' THEN '5'
		  WHEN  DATEPART(WEEKDAY, OrderDate)= '6' THEN '6'
		  WHEN  DATEPART(WEEKDAY, OrderDate)= '7' THEN '7'		  
		  ELSE 'workday'
	 END AS WeekDays
INTO Weekdays_table
FROM Orders;
GO

SELECT *
FROM Weekdays_table;
GO

--DayPlus функция прибавляет 5 рабочих дней к исходной дате
CREATE OR ALTER FUNCTION DayPlus(@X int=5)
RETURNS TABLE
AS
RETURN	
	SELECT OrderID, CustomerID, OrderDate, 
	CASE WHEN DATEPART(WEEKDAY, OrderDate)='1' THEN DATEADD (DAY, @X, OrderDate)
		 WHEN DATEPART(WEEKDAY, OrderDate) IN ('2','3','4','5','6') THEN DATEADD (DAY, @X+2, OrderDate)		
		 WHEN DATEPART(WEEKDAY, OrderDate)='7' THEN DATEADD (DAY, @X+1, OrderDate)
		 ELSE 'Unknown'
	END	AS OrderShipment			
	FROM Orders; 
GO	

SELECT * FROM DayPlus(DEFAULT);

------------------------------------------------------------------------------------------
--Задача 5
--Получить заказы нарастающим итогом.

SELECT RID, OrderID, CustomerID, ProductID, OrderDate, UnitPrice, SUM(UnitPrice) OVER (ORDER BY RID) AS SUMGROWTH 
FROM (SELECT Orders.OrderID, CustomerID, ProductID, OrderDate, UnitPrice, row_number() OVER (ORDER BY Orders.OrderID) AS RID
	  FROM Orders
	  JOIN [Order Details] ON [Order Details].OrderID=Orders.OrderID 
     ) SUB
WHERE CustomerID = 'SAVEA'
ORDER BY OrderID;










