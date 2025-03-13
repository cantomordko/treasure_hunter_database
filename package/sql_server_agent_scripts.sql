-- full_backup

USE [msdb]
GO

BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0

IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Database Maintenance' AND category_class=1)
BEGIN
    EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'Database Maintenance'
    IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
END

IF NOT EXISTS (SELECT name FROM msdb.dbo.sysjobs WHERE name=N'full_backup.Subplan_1')
BEGIN
    DECLARE @jobId BINARY(16)
    EXEC @ReturnCode = msdb.dbo.sp_add_job @job_name=N'full_backup.Subplan_1', 
            @enabled=1, 
            @notify_level_eventlog=2, 
            @notify_level_email=0, 
            @notify_level_netsend=0, 
            @notify_level_page=0, 
            @delete_level=0, 
            @description=N'No description available.', 
            @category_name=N'Database Maintenance', 
            @owner_login_name=N'AMPLUSFOODS\wiktor.piotrowski', @job_id = @jobId OUTPUT
    IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

    EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Subplan_1', 
            @step_id=1, 
            @cmdexec_success_code=0, 
            @on_success_action=1, 
            @on_success_step_id=0, 
            @on_fail_action=2, 
            @on_fail_step_id=0, 
            @retry_attempts=0, 
            @retry_interval=0, 
            @os_run_priority=0, @subsystem=N'SSIS', 
            @command=N'/Server "$(ESCAPE_NONE(SRVR))" /SQL "Maintenance Plans\full_backup" /set "\Package\Subplan_1.Disable;false"', 
            @flags=0
    IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

    EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
    IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

    EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'every_1_day', 
            @enabled=1, 
            @freq_type=4, 
            @freq_interval=1, 
            @freq_subday_type=1, 
            @freq_subday_interval=0, 
            @freq_relative_interval=0, 
            @freq_recurrence_factor=0, 
            @active_start_date=20250313, 
            @active_end_date=99991231, 
            @active_start_time=20000, 
            @active_end_time=235959, 
            @schedule_uid=N'56d67a3e-f10a-4381-9822-ad742599a1de'
    IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

    EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
    IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
END

COMMIT TRANSACTION
GOTO EndSave

QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO


-- differential_backup

USE [msdb]
GO

BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0

IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Database Maintenance' AND category_class=1)
BEGIN
    EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'Database Maintenance'
    IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
END

IF NOT EXISTS (SELECT name FROM msdb.dbo.sysjobs WHERE name=N'differential_backup.Subplan_1')
BEGIN
    DECLARE @jobId BINARY(16)
    EXEC @ReturnCode = msdb.dbo.sp_add_job @job_name=N'differential_backup.Subplan_1', 
            @enabled=1, 
            @notify_level_eventlog=2, 
            @notify_level_email=0, 
            @notify_level_netsend=0, 
            @notify_level_page=0, 
            @delete_level=0, 
            @description=N'No description available.', 
            @category_name=N'Database Maintenance', 
            @owner_login_name=N'AMPLUSFOODS\wiktor.piotrowski', @job_id = @jobId OUTPUT
    IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

    EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Subplan_1', 
            @step_id=1, 
            @cmdexec_success_code=0, 
            @on_success_action=1, 
            @on_success_step_id=0, 
            @on_fail_action=2, 
            @on_fail_step_id=0, 
            @retry_attempts=0, 
            @retry_interval=0, 
            @os_run_priority=0, @subsystem=N'SSIS', 
            @command=N'/Server "$(ESCAPE_NONE(SRVR))" /SQL "Maintenance Plans\differential_backup" /set "\Package\Subplan_1.Disable;false"', 
            @flags=0
    IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

    EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
    IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

    EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'every_4_h', 
            @enabled=1, 
            @freq_type=4, 
            @freq_interval=1, 
            @freq_subday_type=8, 
            @freq_subday_interval=4, 
            @freq_relative_interval=0, 
            @freq_recurrence_factor=0, 
            @active_start_date=20250313, 
            @active_end_date=99991231, 
            @active_start_time=0, 
            @active_end_time=200000, 
            @schedule_uid=N'91fe8b96-872f-473c-9ade-c0cdb15e5cb1'
    IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

    EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
    IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
END

COMMIT TRANSACTION
GOTO EndSave

QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO


-- transaction_backup

USE [msdb]
GO

BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0

IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Database Maintenance' AND category_class=1)
BEGIN
    EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'Database Maintenance'
    IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
END

IF NOT EXISTS (SELECT name FROM msdb.dbo.sysjobs WHERE name=N'transaction_backup.Subplan_1')
BEGIN
    DECLARE @jobId BINARY(16)
    EXEC @ReturnCode = msdb.dbo.sp_add_job @job_name=N'transaction_backup.Subplan_1', 
            @enabled=1, 
            @notify_level_eventlog=2, 
            @notify_level_email=0, 
            @notify_level_netsend=0, 
            @notify_level_page=0, 
            @delete_level=0, 
            @description=N'No description available.', 
            @category_name=N'Database Maintenance', 
            @owner_login_name=N'AMPLUSFOODS\wiktor.piotrowski', @job_id = @jobId OUTPUT
    IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

    EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Subplan_1', 
            @step_id=1, 
            @cmdexec_success_code=0, 
            @on_success_action=1, 
            @on_success_step_id=0, 
            @on_fail_action=2, 
            @on_fail_step_id=0, 
            @retry_attempts=0, 
            @retry_interval=0, 
            @os_run_priority=0, @subsystem=N'SSIS', 
            @command=N'/Server "$(ESCAPE_NONE(SRVR))" /SQL "Maintenance Plans\transaction_backup" /set "\Package\Subplan_1.Disable;false"', 
            @flags=0
    IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

    EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
    IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

    EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'every_1_h', 
            @enabled=1, 
            @freq_type=4, 
            @freq_interval=1, 
            @freq_subday_type=8, 
            @freq_subday_interval=1, 
            @freq_relative_interval=0, 
            @freq_recurrence_factor=0, 
            @active_start_date=20250313, 
            @active_end_date=99991231, 
            @active_start_time=180000, 
            @active_end_time=80000, 
            @schedule_uid=N'1f7698e7-c2a5-4b91-99ee-d36d43bd221f'
    IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

    EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'every_15_min', 
            @enabled=1, 
            @freq_type=4, 
            @freq_interval=1, 
            @freq_subday_type=4, 
            @freq_subday_interval=15, 
            @freq_relative_interval=0, 
            @freq_recurrence_factor=0, 
            @active_start_date=20250313, 
            @active_end_date=99991231, 
            @active_start_time=80000, 
            @active_end_time=180000, 
            @schedule_uid=N'45e83a5f-4012-482f-a8b6-b65244320ae9'
    IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

    EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
    IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
END

COMMIT TRANSACTION
GOTO EndSave

QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO


-- check_db_integrity

USE [msdb]
GO

BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0

IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Database Maintenance' AND category_class=1)
BEGIN
    EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'Database Maintenance'
    IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
END

IF NOT EXISTS (SELECT name FROM msdb.dbo.sysjobs WHERE name=N'checkdb_integrity.Subplan_1')
BEGIN
    DECLARE @jobId BINARY(16)
    EXEC @ReturnCode = msdb.dbo.sp_add_job @job_name=N'checkdb_integrity.Subplan_1', 
            @enabled=1, 
            @notify_level_eventlog=2, 
            @notify_level_email=0, 
            @notify_level_netsend=0, 
            @notify_level_page=0, 
            @delete_level=0, 
            @description=N'No description available.', 
            @category_name=N'Database Maintenance', 
            @owner_login_name=N'AMPLUSFOODS\wiktor.piotrowski', @job_id = @jobId OUTPUT
    IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

    EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Subplan_1', 
            @step_id=1, 
            @cmdexec_success_code=0, 
            @on_success_action=1, 
            @on_success_step_id=0, 
            @on_fail_action=2, 
            @on_fail_step_id=0, 
            @retry_attempts=0, 
            @retry_interval=0, 
            @os_run_priority=0, @subsystem=N'SSIS', 
            @command=N'/Server "$(ESCAPE_NONE(SRVR))" /SQL "Maintenance Plans\checkdb_integrity" /set "\Package\Subplan_1.Disable;false"', 
            @flags=0
    IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

    EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
    IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

    EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'every_1_day', 
            @enabled=1, 
            @freq_type=4, 
            @freq_interval=1, 
            @freq_subday_type=1, 
            @freq_subday_interval=0, 
            @freq_relative_interval=0, 
            @freq_recurrence_factor=0, 
            @active_start_date=20250313, 
            @active_end_date=99991231, 
            @active_start_time=10000, 
            @active_end_time=235959, 
            @schedule_uid=N'a0dd26b4-79af-4c84-a864-8942aa666c34'
    IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

    EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
    IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
END

COMMIT TRANSACTION
GOTO EndSave

QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO