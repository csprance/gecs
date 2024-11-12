## TODO: I dunno about this yet
## An archetype is a collection of components. We can assign an Entity to a specific archetype
## and that entity will be stored alongside other entites of the same archetype to speed up queries
## Then all we need to do is run the query builder on the specific archetype storage to refine the query
class_name Archetype
extends Entity

var is_archetype = true

## What [Component]s this archetype should use[br]
## Return a list of [Component]s to be used
func uses():
    return []

## Called
func setup():
    pass

## Function used to get the signature of the archetype
func signature():
    var keys = uses().map(func(x): x.get_script().resource_path)
    keys.sort()

    return '-'.join(keys)
