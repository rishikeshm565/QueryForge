Windows PowerShell
Copyright (C) Microsoft Corporation. All rights reserved.

PS C:\Users\rishi> cd D:\QueryForge
PS D:\QueryForge> notepad .\sql\practice\day75_backup_restore.py
PS D:\QueryForge> cd D:\QueryForge
PS D:\QueryForge>
PS D:\QueryForge> py -m py_compile .\sql\practice\day75_backup_restore.py .\sql\practice\test_day75_backup_restore.py
  File ".\sql\practice\day75_backup_restore.py", line 247
    lines = [
            ^
SyntaxError: '[' was never closed
PS D:\QueryForge>
PS D:\QueryForge> if ($LASTEXITCODE -ne 0) {
>>     throw "Python syntax still has an error"
>> }
Python syntax still has an error
At line:2 char:5
+     throw "Python syntax still has an error"
+     ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : OperationStopped: (Python syntax still has an error:String) [], RuntimeException
    + FullyQualifiedErrorId : Python syntax still has an error

PS D:\QueryForge>
PS D:\QueryForge> py -m pytest -q .\sql\practice\test_day75_backup_restore.py

========================================================================= ERRORS ==========================================================================
_______________________________________________ ERROR collecting sql/practice/test_day75_backup_restore.py ________________________________________________
C:\Users\rishi\AppData\Local\Python\pythoncore-3.14-64\Lib\site-packages\_pytest\python.py:508: in importtestmodule
    mod = import_path(
C:\Users\rishi\AppData\Local\Python\pythoncore-3.14-64\Lib\site-packages\_pytest\pathlib.py:596: in import_path
    importlib.import_module(module_name)
C:\Users\rishi\AppData\Local\Python\pythoncore-3.14-64\Lib\importlib\__init__.py:88: in import_module
    return _bootstrap._gcd_import(name[level:], package, level)
           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
<frozen importlib._bootstrap>:1406: in _gcd_import
    ???
<frozen importlib._bootstrap>:1371: in _find_and_load
    ???
<frozen importlib._bootstrap>:1342: in _find_and_load_unlocked
    ???
<frozen importlib._bootstrap>:938: in _load_unlocked
    ???
C:\Users\rishi\AppData\Local\Python\pythoncore-3.14-64\Lib\site-packages\_pytest\assertion\rewrite.py:188: in exec_module
    exec(co, module.__dict__)
sql\practice\test_day75_backup_restore.py:10: in <module>
    from day75_backup_restore import (
E     File "D:\QueryForge\sql\practice\day75_backup_restore.py", line 247
E       lines = [
E               ^
E   SyntaxError: '[' was never closed
================================================================= short test summary info =================================================================
ERROR sql/practice/test_day75_backup_restore.py
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! Interrupted: 1 error during collection !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
1 error in 0.13s
PS D:\QueryForge>
PS D:\QueryForge> if ($LASTEXITCODE -ne 0) {
>>     throw "Day 75 tests failed"
>> }
Day 75 tests failed
At line:2 char:5
+     throw "Day 75 tests failed"
+     ~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : OperationStopped: (Day 75 tests failed:String) [], RuntimeException
    + FullyQualifiedErrorId : Day 75 tests failed

PS D:\QueryForge>
PS D:\QueryForge> Write-Host "DAY 75 PYTHON FIX: PASS"
DAY 75 PYTHON FIX: PASS
PS D:\QueryForge> cd D:\QueryForge
PS D:\QueryForge> notepad .\scripts\day75_run.ps1
PS D:\QueryForge>