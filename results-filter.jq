[ foreach inputs as $item (0; .+1; {config: $ARGS.positional[.-1], results: $item}) ]
| . as $runs
| [$runs[].results.tests.[] | select(.metrics.["regalloc.NumSpills"] != null) | .name]
| unique
| map(. as $name | {
	name: $name,
	results: $runs | map(. as $run | $run.results.tests.[] | select(.name == $name) as $result | {
		config: $run.config,
		elapsed: $result.elapsed,
		spills: $result.metrics.["regalloc.NumSpills"]
	})
})
