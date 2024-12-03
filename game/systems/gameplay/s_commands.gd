## The CommandsSystem is responsible for executing the commands of the entities as well as handling the undo of commands if needed
class_name CommandsSystem
extends System

## We track all the executed commands for reasons I don't know yet :)
var executed_commands: Array = []

func query():
    return q.with_all([C_Command])

func process(entity, _delta: float):
    # get the command component
    var c_command = entity.get_component(C_Command) as C_Command
    # execute the command
    var results = c_command.command.call()
    # Store the executed command metadata and results (if any)
    executed_commands.append({
        [c_command.name]: c_command.meta, 
        'results': results # This could be null if the command doesn't return anything
    })
    # remove the command component after processing
    entity.remove_component(C_Command)
