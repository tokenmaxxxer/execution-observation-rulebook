# todo-cli

A tiny file-backed todo list. Python 3, stdlib only.

## Usage

```
python3 todo.py add Buy milk        # add an item
python3 todo.py list                # numbered list; [x] marks completed items
python3 todo.py done 1              # complete an item (ids as shown by list)
python3 todo.py remove 1            # delete an item (ids as shown by list)
python3 todo.py export out.csv      # every item with its status, as CSV
```

Data lives in `todos.json` next to the script.
