DECLARE @table NVARCHAR(MAX), @coreguid NVARCHAR(MAX), @row NVARCHAR(MAX), @log_file NVARCHAR(MAX), @iteration INT, @totalrows INT, @batchsize NVARCHAR(MAX), @msg VARCHAR(MAX), @delay nvarchar(max);
SET @batchsize = 100000
SET @delay = '00:00:00.1'
SET @coreguid = 'b07fe0f5-aff0-4755-9a76-ff030ca951af' --change this to the coreguid you want to delete
SELECT @log_file = name FROM sys.master_files WHERE database_id = DB_ID() AND type = 1

DECLARE tbl cursor for
	SELECT DISTINCT TABLE_NAME, ROW_NUMBER() OVER(ORDER BY TABLE_NAME ASC) AS RowNum FROM information_schema.columns WHERE COLUMN_NAME LIKE 'coreguid' AND TABLE_NAME NOT IN (SELECT NAME FROM SYS.VIEWS)
	
OPEN tbl
FETCH NEXT FROM tbl INTO @table, @row
WHILE @@FETCH_STATUS = 0
BEGIN
	DECLARE @percent NVARCHAR(MAX), @sql NVARCHAR(MAX), @cleanlog NVARCHAR(MAX), @r int, @tblname NVARCHAR(MAX), @perc nvarchar(max)
	SET NOCOUNT ON;
	SET @iteration = 0 
	SET @totalrows = 0 
	SELECT @percent = (@row * 100 / @@CURSOR_ROWS)
	SELECT @r = 1, @sql = 'delete top(' + @batchsize + ') FROM ' + @table + ' WHERE coreguid = ''' + @coreguid + '''', @tblname = @table + ' --------------------'
	RAISERROR  (@tblname, 0, 1) with NOWAIT
	WHILE @r > 0 
	BEGIN
		BEGIN TRANSACTION;
		EXEC (@sql)
		SET @r = @@ROWCOUNT
		SET @iteration=@iteration+1
		SET @totalrows=@totalrows+@batchsize
		SET @msg = 'Iteration: ' + CAST(@iteration AS VARCHAR) + ' Total deletes:' + CAST(@totalrows AS VARCHAR) + ' Percent Complete (Total):' + @percent
		RAISERROR (@msg, 0, 1) WITH NOWAIT
		COMMIT TRANSACTION;
		CHECKPOINT
		WAITFOR DELAY @delay
	END
	FETCH NEXT FROM tbl INTO @table, @row
END
CLOSE tbl
DEALLOCATE tbl