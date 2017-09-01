use ldms20171
-- This script will alter columns on tables 2 at a time. There's a much better way to organize this script so that it's easier to understand but I'm not ready to rewrite it. In the top cursor just add a select statement that has the table name up to two columns afterward.
-- example: select 'tablename','column1','column2'
-- If you need to add more then just put a union all after your statement and make sure that the select statment starting on line 6 works. If that works, then the rest of the script should work.
declare @t nvarchar(max), @c nvarchar(max), @cc nvarchar(max), @cn nvarchar(max), @ccn nvarchar(max)
			declare alt cursor for
				select t.tbl, t.col1, t.col2, t.col1len, t.col2len from (select 'EnvironSettings' as tbl, 'Name' as col1, '1024' as col1len, 'ValueString' as col2, '600' as col2len
								union all
								select 'Services', 'Path', 'max', 'Description', 'max'
								union all
								select 'Printer', 'Version', 'max', null, null
								union all
								select 'PeripheralAdapters', 'Type', 'max', null, null
								union all
								select 'Video', 'DriverName', 'max', null, null) t
open alt
fetch next from alt into @t, @c, @cc, @cn, @ccn
while @@FETCH_STATUS = 0
begin
	declare @table nvarchar(255) = @t, @cso nvarchar(255), @pub nvarchar(255),
			@view nvarchar(255), @guid nvarchar(50), @server nvarchar(255), @destDB nvarchar(255), @destTable nvarchar(255), 
			@fireTrigger nvarchar (10), @colName nvarchar(255),	@article nvarchar(max), @columns nvarchar(max) = '', 
			@index nvarchar(max), @viewSQL nvarchar(max), @cmd nvarchar(512)

	if (exists (select * From sys.tables where name = 'syssubscriptions'))
	begin
		select @view = CONCAT('Repl', @table, 'V')
		select @cso = CONCAT(@table, 'CSO')
		select @pub = CONCAT('LDMS_', db_name())

		if (exists(select * from INFORMATION_SCHEMA.views  where table_name = @view))
		BEGIN
			select @guid = upper(systemguid) from metasystems where system_idn = 0
			select top(1) @destDB = dest_db, @server = srvname from syssubscriptions
			if (@destDB is not null AND @server is not null)
			BEGIN
				select @destTable = dest_table, @fireTrigger = case when 1 = fire_triggers_on_snapshot then 'TRUE' else 'FALSE' end from sysarticles where name = @cso
				select @article = 'sp_addarticle @publication = ''' + @pub + ''', @article=''' + @cso + ''', @source_object=''' + @view + ''', @destination_table=''' + @destTable + ''', @type=''indexed view logbased'', @sync_object=''' + @view + ''', @pre_creation_cmd=''delete'', @schema_option=0x00, @status=24, @ins_cmd=''CALL sp_LD' + CONCAT('ins_', @table) + ''', @del_cmd=''CALL sp_LD' + CONCAT('del_', @table) + ''', @upd_cmd=''MCALL sp_LD' + CONCAT('upd_', @table) + ''', @fire_triggers_on_snapshot=''' + @fireTrigger + '''';
				select @viewSQL = view_definition from information_schema.views where table_name = @view

				DECLARE columnsCursor CURSOR FOR
				select a.name from sys.columns a, sys.indexes b, sys.index_columns c where a.object_id = b.object_id and b.object_id = c.object_id and c.column_id = a.column_id and b.name = CONCAT('PK', @view) order by c.key_ordinal
				OPEN columnsCursor
				FETCH NEXT FROM columnsCursor into @colName
				WHILE @@FETCH_STATUS = 0
				BEGIN
					select @columns = CONCAT(@columns, case when len(@columns) = 0 then @colName else CONCAT(', ', @colName) end)
					FETCH NEXT FROM columnsCursor into @colName
				END
				CLOSE columnsCursor
				DEALLOCATE columnsCursor
				select @index = 'CREATE UNIQUE CLUSTERED INDEX ' + CONCAT('PK', @view) + ' on ' + @view + ' (' + @columns + ')'

				select @cmd = 'sp_dropsubscription @publication=''' + @pub + ''', @article=''' + @cso + ''', @subscriber=''' + @server + ''''
				exec sp_executesql @cmd

				select @cmd = 'sp_droparticle @publication=''' + @pub + ''', @article=''' + @cso + ''''
				exec sp_executesql @cmd

				select @cmd = 'drop view ' + @view
				exec sp_executesql @cmd
			
				
				select @cmd = 'ALTER TABLE ' + @t + ' ALTER COLUMN ' + @c + ' nvarchar(' + @cn + ')'
				exec sp_executesql @cmd

				if (@cc <> null)
				begin
					select @cmd = 'ALTER TABLE ' + @t + ' ALTER COLUMN ' + @cc + ' nvarchar(' + @ccn + ')'
					exec sp_executesql @cmd
				end

				exec sp_executesql @viewSQL
				exec sp_executesql @index
				exec sp_executesql @article
				if (exists(select column_name from information_schema.columns where table_name = @view and column_name = 'CoreGUID'))
				begin
					select @cmd = 'sp_articlefilter @publication = ''' + @pub + ''', @article=''' + @cso + ''', @filter_name=''' + CONCAT('CoreGuid', @table) + ''', @filter_clause=''CoreGuid = cast(''''' + @guid + ''''' as uniqueidentifier)'''
					exec sp_executesql @cmd
				end
			
				select @cmd = 'sp_addsubscription @publication=''' + @pub + ''', @article=''' + @cso + ''', @subscriber=''' + @server + ''', @destination_db=''' + @destDB + ''', @subscription_type=''pull'', @update_mode=''read only'''
				exec sp_executesql @cmd
			END
		END
	end
	fetch next from alt into @t, @c, @cc, @cn, @ccn
end
close alt
deallocate alt