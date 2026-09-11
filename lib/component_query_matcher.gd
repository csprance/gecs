## ComponentQueryMatcher
## Static utility for matching components against query criteria.
## Used by QueryBuilder and Relationship systems for consistent component filtering.
##
## Supports comparison operators (_gt, _lt, _eq), array membership (_in, _nin),
## and custom functions for property-based filtering.
##
## [b]Query Operators:[/b]
## [br]• [b]_eq:[/b] Equal [code]property == value[/code]
## [br]• [b]_ne:[/b] Not equal [code]property != value[/code]
## [br]• [b]_gt:[/b] Greater than [code]property > value[/code]
## [br]• [b]_lt:[/b] Less than [code]property < value[/code]
## [br]• [b]_gte:[/b] Greater or equal [code]property >= value[/code]
## [br]• [b]_lte:[/b] Less or equal [code]property <= value[/code]
## [br]• [b]_in:[/b] In array [code]property in [values][/code]
## [br]• [b]_nin:[/b] Not in array [code]property not in [values][/code]
## [br]• [b]func:[/b] Custom function [code]func(property) -> bool[/code]
##
## [codeblock]
##     var component = C_Health.new(75)
##     var query = {"health": {"_gte": 50, "_lte": 100}}
##     var matches = ComponentQueryMatcher.matches_query(component, query)
##
##     # Custom functions
##     var func_query = {"level": {"func": func(level): return level >= 40}}
##
##     # Array membership
##     var type_query = {"type": {"_in": ["fire", "ice"]}}
## [/codeblock]
class_name ComponentQueryMatcher
extends RefCounted

## Checks if a component matches the given query criteria.
## All query operators must pass for the component to match.
##
## [param component]: The [Component] to evaluate
## [param query]: Dictionary mapping property names to operator dictionaries
## [return]: [code]true[/code] if all criteria match, [code]false[/code] otherwise
##
## Returns [code]true[/code] for empty queries. Returns [code]false[/code] if any
## property doesn't exist or any operator fails.
static func matches_query(component: Component, query: Dictionary) -> bool:
	if query.is_empty():
		return true

	for property in query:
		# Check if property exists (can't use truthiness check because 0, false, etc. are valid values)
		if not property in component:
			return false

		var property_value = component.get(property)
		var property_query = query[property]

		for operator in property_query:
			match operator:
				"func":
					if not property_query[operator].call(property_value):
						return false
				"_eq":
					if property_value != property_query[operator]:
						return false
				"_gt":
					if property_value <= property_query[operator]:
						return false
				"_lt":
					if property_value >= property_query[operator]:
						return false
				"_gte":
					if property_value < property_query[operator]:
						return false
				"_lte":
					if property_value > property_query[operator]:
						return false
				"_ne":
					if property_value == property_query[operator]:
						return false
				"_nin":
					if property_value in property_query[operator]:
						return false
				"_in":
					if not (property_value in property_query[operator]):
						return false

	return true

## Separates component types from query dictionaries in a mixed array.
## Used by QueryBuilder to process component lists that may contain queries.
##
## [param components]: Array of [Component] classes and/or query dictionaries
## [return]: Dictionary with [code]"components"[/code] and [code]"queries"[/code] arrays
##
## Regular components get empty query dictionaries. Query dictionaries are
## split into their component type and criteria.
static func process_component_list(components: Array) -> Dictionary:
	var result := {"components": [], "queries": []}

	for component in components:
		if component is Dictionary:
			# Handle component query case
			for component_type in component:
				result.components.append(component_type)
				result.queries.append(component[component_type])
		else:
			# Handle regular component case
			result.components.append(component)
			result.queries.append({}) # Empty query for regular components (matches all)

	return result
