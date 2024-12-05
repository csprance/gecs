# Query DSL
> A DSL that allows you to describe relationships that can be compiled down as a gd script file

## Examples
### Named Query
If you give a query a name it will use that for the file name
```
QUERY MyCustomQueryName(
    ALL(C_Transform, C_Velocity)
    ANY(C_AngularVelocity)
    NONE(C_PendingDelete)
    WITH([C_FiredBy, *], [C_Tracking, *])
    WITHOUT([C_CollidedWith, *])
)
```
```python [compiled_queries/my_custom_query.gd]
q
.with_all([C_Transform, C_Velocity])
.with_any([C_AngularVelocity])
.with_none([C_PendingDelete])
.with_relationship([
	Relationship.new(C_FiredBy.new(), ECS.wildcard), 
	Relationship.new(C_FiredBy.new(), ECS.wildcard)]
)
.without_relationship([
   Relationship.new(C_CollidedWith.new(), ECS.wildcard), 
])
```
### Without Name
If you don't give it a query it will hash the contents and use that
```
QUERY(
    ALL(C_Transform)
    NONE(C_PendingDelete)
)
```
```python [compiled_queries/[hash].gd]
q
.with_all([C_Transform])
.with_none([C_PendingDelete])
```
