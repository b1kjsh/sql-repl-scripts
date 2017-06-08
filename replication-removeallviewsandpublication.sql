declare @databasename nvarchar(max), @view nvarchar(max), @sql nvarchar(max), @msg nvarchar(max), @error nvarchar(max)

select @databasename = DB_NAME()

if(exists(select top(1) * from syssubscriptions))
begin
	--TODO: get publication name
	exec sp_droppublication @publication=''
end
else
begin
	select @msg = 'No publications for this database were found'
	RAISERROR(@msg, 0, 1) with nowait
end
if(exists(select * from sys.views where name like 'Repl%'))
begin
	select @msg = 'Found ''Repl'' views... '
	RAISERROR(@msg, 0, 1) with nowait
	declare viewcur cursor for 
		select name from sys.views where name like 'Repl%'

		open viewcur
		fetch next from viewcur into @view
		while @@FETCH_STATUS = 0
		begin
			begin try
				set @sql = 'drop view ' + @view
				exec (@sql)
				select @msg = 'Successfully dropped view ' + @view
				RAISERROR(@msg, 0, 1) with nowait
			end try
			begin catch
				select @error = ERROR_MESSAGE()
				select @msg = 'Failed to drop view ' + @view + ' with error ' + @error
				RAISERROR(@msg, 0, 1) with nowait
			end catch
			fetch next from viewcur into @view
		end
		close viewcur
		deallocate viewcur
end
else
begin
	select @msg = 'No ''Repl'' views were found'
	RAISERROR(@msg, 0, 1) with nowait
end