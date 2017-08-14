declare @sql nvarchar(max), @def nvarchar(max), @content nvarchar(max), @name nvarchar(max)
declare cur cursor for
	select 
	SUBSTRING(Replace(definition,'[dbo].',''), CHARINDEX('[',Replace(definition,'[dbo].','')) + 1, CHARINDEX(']',Replace(definition,'[dbo].','')) - CHARINDEX('[',Replace(definition,'[dbo].','')) - 1) as [name],
	LEFT([definition], CHARINDEX('BEGIN', [definition]) - 1) as [def],
	REPLACE(SUBSTRING([definition], CHARINDEX('BEGIN', [definition]), LEN([definition])), '', 'asdfasdfasdfasdf') AS [content]
	from sys.sql_modules 
	where definition like '%sp_LDins%'
open cur
fetch next from cur into @name, @def, @content
while @@FETCH_STATUS = 0
begin
	declare @parameters nvarchar(max) = '', @param nvarchar(max), @datatype nvarchar(max), @parameter nvarchar(max) = '';

	select @parameter = PARAMETER_NAME from INFORMATION_SCHEMA.PARAMETERS where DATA_TYPE = 'uniqueidentifier' and PARAMETER_NAME not like '@pkc%' and SPECIFIC_NAME = @name
	--select charindex('uniqueidentifier',@def), @def;
	declare p cursor for
		select PARAMETER_NAME, DATA_TYPE from INFORMATION_SCHEMA.PARAMETERS where PARAMETER_NAME not like '@pkc%' and SPECIFIC_NAME = @name
	open p
	fetch next from p into @param, @datatype
	while @@FETCH_STATUS = 0 
	begin
		set @parameters += '''' + @param + ''' + '' = ''' + ' + CAST(' + @param + ' as NVARCHAR(max)) + ' + ''';'''
		fetch next from p into @param, @datatype
		if (@@FETCH_STATUS = 0)
			set @parameters += ' + '
	end
	close p
	deallocate p

	--RAISERROR (@parameters, 0, 1) WITH NOWAIT
	select @sql = replace(@def,'CREATE PROCEDURE','ALTER PROCEDURE') + '
BEGIN
BEGIN TRY 
' + @content + '
END TRY
BEGIN CATCH 
		declare @error int, @message varchar(4000), @xstate int, @procname nvarchar(50);
		select @error = ERROR_NUMBER(), @message = ERROR_MESSAGE(), @xstate = XACT_STATE(), @procname = error_procedure();
		INSERT INTO jh_exceptions (error, message, xstate, procname, params, coreguid) values (@error, @message, @xstate, @procname,' + @parameters + ', ' + @parameter + ');
END CATCH
END';
	--SELECT @sql;
	--set @sql = '';
	RAISERROR (@name, 0, 1) WITH NOWAIT
	--exec (@sql)

	fetch next from cur into @name, @def, @content;
end
close cur
deallocate cur