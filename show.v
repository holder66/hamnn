// show.v
// in order to establish style consistency, aim to use magenta underline
// for the first line of each output, and blue underline for table headings.
// use bold green for subheadings
// ie, println(chalk.fg(chalk.style('\nfirst line', 'underline'), 'magenta'))
// println(chalk.fg(chalk.style('table header','underline'), 'blue'))
// println(chalk.fg(chalk.style('subheading','bold'), 'green'))
//
// this website https://towardsdatascience.com/multi-class-metrics-made-simple-part-ii-the-f1-score-ebe8b2c2ca1 gives the
// best explanation of multiclass metrics and how they're calculated

module hamnn

import etienne_napoleone.chalk
import arrays
import strings
// import math

// pad
fn pad(l int) string {
	return strings.repeat(' '[0], l)
}

// show_analyze prints out to the console, a series of tables detailing a
// dataset. It takes as input an AnalyzeResult struct generated by
// analyze_dataset().
pub fn show_analyze(result AnalyzeResult) {
	mut show := []string{}
	println(chalk.fg(chalk.style('\nAnalysis of Dataset "$result.datafile_path" (File Type $result.datafile_type)',
		'underline'), 'magenta'))
	println(chalk.fg(chalk.style('All Attributes', 'bold'), 'green'))
	println(chalk.fg(chalk.style(' Index  Name                          Count  Uniques  Missing      %  Type',
		'underline'), 'blue'))

	for attr in result.attributes {
		show << '${attr.id:6}  ${attr.name:-27}  ${attr.count:6}  ${attr.uniques:7}  ${attr.missing:7}  ${attr.missing * 100 / f32(attr.count):5.1f}  ${attr.att_type:4}'
	}
	mut total_count := 0
	mut total_missings := 0
	for attr in result.attributes {
		total_count += attr.count
		total_missings += attr.missing
	}
	show << [
		'_______                             _______           _______  _____',
		'Totals (less Class attribute)    ${total_count:10}        ${total_missings:10}  ${total_missings * 100 / f32(total_count):5.2f}%',
	]
	print_array(show)
	show = []
	println(chalk.fg(chalk.style('Counts of Attributes by Type', 'bold'), 'green'))
	println(chalk.fg(chalk.style('Type        Count', 'underline'), 'blue'))
	mut types := []string{}
	for attr in result.attributes {
		types << attr.att_type
	}
	for key, value in string_element_counts(types) {
		show << '$key          ${value:6}'
	}
	show << 'Total:     ${types.len:6}'
	print_array(show)
	show = []
	disc_atts := result.attributes.filter(it.for_training && it.att_type == 'D')
	println(chalk.fg(chalk.style('Discrete Attributes for Training', 'bold'), 'green') +
		' ($disc_atts.len attributes)')
	println(chalk.fg(chalk.style(' Index  Name                        Uniques', 'underline'),
		'blue'))
	for attr in disc_atts {
		show << '${attr.id:6}  ${attr.name:-27} ${attr.uniques:7}'
	}
	print_array(show)

	show = []
	cont_atts := result.attributes.filter(it.for_training && it.att_type == 'C')
	println(chalk.fg(chalk.style('Continuous Attributes for Training', 'bold'), 'green') +
		' ($cont_atts.len attributes)')

	println(chalk.fg(chalk.style(' Index  Name                               Min         Max',
		'underline'), 'blue'))
	for attr in cont_atts {
		show << '${attr.id:6}  ${attr.name:-27} ${attr.min:10.3g}  ${attr.max:10.3g}'
	}
	print_array(show)

	show = []
	println(chalk.fg(chalk.style('The Class Attribute: "$result.class_name"', 'bold'), 'green') +
		' ($result.class_counts.len classes)')
	println(chalk.fg(chalk.style('Class Value           Cases', 'underline'), 'blue'))
	for key, value in result.class_counts {
		show << '${key:-20}  ${value:5}'
	}
	print_array(show)
}

// show_rank_attributes
fn show_rank_attributes(result RankingResult) {
	mut exclude_phrase := 'included'
	if result.exclude_flag {
		exclude_phrase = 'excluded'
	}
	println(chalk.fg(chalk.style('\nAttributes Sorted by Rank Value, for "$result.path"',
		'underline'), 'magenta'))
	println('Missing values: $exclude_phrase')
	println('Bin range for continuous attributes: from $result.binning.lower to $result.binning.upper with interval $result.binning.interval')
	println(chalk.fg(chalk.style(' Index  Name                         Type   Rank Value   Bins',
		'underline'), 'blue'))
	mut array_to_print := []string{}
	for attr in result.array_of_ranked_attributes {
		array_to_print << '${attr.attribute_index:6}  ${attr.attribute_name:-27} ${attr.inferred_attribute_type:2}         ${attr.rank_value:7.2f} ${attr.bins:6}'
	}
	print_array(array_to_print)
}

// show_classifier outputs to the console information about a classifier
pub fn show_classifier(cl Classifier) {
	println(chalk.fg(chalk.style('\nClassifier for "$cl.datafile_path"', 'underline'),
		'magenta'))
	// println('options: missing values ' + if cl.exclude_flag { 'excluded' } else { 'included' } +
	// 	' when calculating rank values')
	// println('Included attributes: $cl.trained_attributes.len\nTrained on $cl.instances.len instances.')
	// println('Bin range for continuous attributes: from $cl.binning.lower to $cl.binning.upper with interval $cl.binning.interval')
	show_parameters(cl.Parameters)
	println(chalk.fg(chalk.style('Index  Attribute                   Type  Rank Value   Uniques       Min        Max  Bins',
		'underline'), 'blue'))
	for attr, val in cl.trained_attributes {
		println('${val.index:5}  ${attr:-27} ${val.attribute_type:-4}  ${val.rank_value:10.2f}' +
			if val.attribute_type == 'C' { '          ${val.minimum:10.2f} ${val.maximum:10.2f} ${val.bins:5}' } else { '      ${val.translation_table.len:4}' })
	}
	println(chalk.fg(chalk.style('\nClassifier History:', 'bold'), 'green'))
	println(chalk.fg(chalk.style(
		'Date & Time (UTC)    Event   From file                   Original Instances' +
		if cl.purge_flag { '  After purging' } else { '' }, 'underline'), 'blue'))
	// println(chalk.fg(chalk.style('Date & Time (UTC)    Event   From file                   Original Instances  After purging',
	// 'underline'), 'blue'))
	for events in cl.history {
		println(
			'${events.event_date:-19}  ${events.event:-6}  ${events.file_path:-35} ${events.prepurge_instances_count:10}' +
			if cl.purge_flag { ' ${events.instances_count:14}' } else { '' })
	}
}

// show_parameters
fn show_parameters(p Parameters) {
	exclude_string := if p.exclude_flag { 'excluded' } else { 'included' }
	attr_string := if p.number_of_attributes[0] == 0 {
		'all'
	} else {
		p.number_of_attributes[0].str()
	}
	purge_string := if p.purge_flag { 'on' } else { 'off' }
	weight_string := if p.weighting_flag { 'yes' } else { 'no' }
	results_array := [
		'Attributes: $attr_string',
		'Missing values: $exclude_string',
		if p.binning.lower == 0 {
			'No continuous attributes, thus no binning'
		} else {
			'Bin range for continuous attributes: from $p.binning.lower to $p.binning.upper with interval $p.binning.interval'
		},
		'Prevalence weighting of nearest neighbor counts: $weight_string ',
		'Purging of duplicate instances: $purge_string',
	]
	print_array(results_array)
}

// show_validate
fn show_validate(result ValidateResult) {
	println(chalk.fg(chalk.style('\nValidation of "$result.validate_file_path" using a classifier from "$result.classifier_path"',
		'underline'), 'magenta'))
	show_parameters(result.Parameters)
	if result.purge_flag {
		total_count := result.prepurge_instances_counts_array[0]
		purged_count := total_count - result.classifier_instances_counts[0]
		purged_percent := 100 * f64(purged_count) / total_count
		println('Instances purged: $purged_count out of $total_count (${purged_percent:6.2f}%)')
	}
	println('Number of instances validated: $result.inferred_classes.len')
	println('Inferred classes: $result.inferred_classes')
	println('For classes: $result.class_counts.keys() the nearest neighbor counts are:\n$result.counts')
}

// show_verify
fn show_verify(result CrossVerifyResult, settings DisplaySettings) ? {
	// println(result)
	println(chalk.fg(chalk.style('\nVerification of "$result.testfile_path" using a classifier from "$result.classifier_path"',
		'underline'), 'magenta'))
	show_parameters(result.Parameters)
	// println(result)
	if result.purge_flag {
		total_count := result.prepurge_instances_counts_array[0]
		purged_count := total_count - result.classifier_instances_counts[0]
		purged_percent := 100 * f64(purged_count) / total_count
		println('Instances purged: $purged_count out of $total_count (${purged_percent:6.2f}%)')
	}
	show_cross_or_verify_result(result)?
}

// show_crossvalidation
fn show_crossvalidation(result CrossVerifyResult) ? {
	println(chalk.fg(chalk.style('\nCross-validation of "$result.classifier_path"', 'underline'),
		'magenta'))
	println('Partitioning: ' + if result.folds == 0 { 'leave-one-out' } else { '$result.folds-fold' + if result.repetitions > 1 { ', $result.repetitions repetitions' + if result.random_pick { ' with random selection of instances' } else { '' }
		 } else { ''
		 }
	 })
	show_parameters(result.Parameters)
	if result.purge_flag {
		total_count_avg := arrays.sum(result.prepurge_instances_counts_array) or {} / f64(result.prepurge_instances_counts_array.len)
		purged_count_avg := total_count_avg - arrays.sum(result.classifier_instances_counts) or {} / f64(result.classifier_instances_counts.len)
		purged_percent := 100 * purged_count_avg / total_count_avg
		println('Average instances purged: ${purged_count_avg:10.1f} out of $total_count_avg (${purged_percent:6.2f}%)')
	}
	show_cross_or_verify_result(result)?
}

// show_cross_or_verify_result
fn show_cross_or_verify_result(result CrossVerifyResult) ? {
	println(chalk.fg(chalk.style('Results:', 'bold'), 'green'))
	// mut metrics := get_metrics(result)?
	if result.expanded_flag {
		percent := (f32(result.correct_count) * 100 / result.labeled_classes.len)
		println('correct inferences: $result.correct_count out of $result.labeled_classes.len (accuracy: raw:${percent:6.2f}% multiclass balanced:${result.balanced_accuracy * 100:6.2f}%)')
	} else {
		show_expanded_result(result.Metrics, result)?
		print_confusion_matrix(result)
	}
}

// show_expanded_result
fn show_expanded_result(metrics Metrics, result CrossVerifyResult) ? {
	println(chalk.fg('    Class                   Instances    True Positives    Precision    Recall    F1 Score',
		'green'))
	show_multiple_classes_stats(result)?
	if result.class_counts.len == 2 {
		println('A correct classification to "${result.pos_neg_classes[0]}" is a True Positive (TP);\nA correct classification to "${result.pos_neg_classes[1]}" is a True Negative (TN).')
		println('Note: for binary classification, balanced accuracy = (sensitivity + specificity) / 2')
		println("   TP    FP    TN    FN  Sens'y Spec'y PPV    NPV    F1 Score  Raw Acc'y  Bal'd")
		println('${get_binary_stats_line(result.BinaryMetrics)}')
	}
}

// get_show_bins
fn get_show_bins(bins []int) string {
	if bins == [] || 0 in bins {
		return '       '
	}
	if bins.len == 1 || bins[0] == bins[1] {
		return '${bins[0]:7}'
	}
	return '${bins[0]:2} - ${bins[1]:-2}'
}


// print_confusion_matrix
fn print_confusion_matrix(result CrossVerifyResult) {
	// collect confusion matrix rows into a matrix
	mut confusion_matrix := [][]f64{}
	mut data_row := []f64{}
	for key, _ in result.confusion_matrix_map {
		data_row = []
		for _, value in result.confusion_matrix_map[key] {
			data_row << value
		}
		confusion_matrix << data_row
	}
	mut header_row := []string{}
	for key, _ in result.confusion_matrix_map {
		header_row << key
	}
	mut display_confusion_matrix := [][]string{}
	mut display_row := []string{}
	for row in confusion_matrix {
		display_row = []
		for col in row {
			display_row << '${col:10.1g}'
		}
		display_confusion_matrix << display_row
	}
	for i, class in header_row {
		display_confusion_matrix[i].prepend(class)
	}
	header_row.prepend('Predicted Classes (columns)')
	display_confusion_matrix.prepend(['Actual Classes (rows)'])
	display_confusion_matrix.prepend(header_row)

	// get the length of the longest class name
	mut l := result.class_counts.keys().map(it.len)
	l << 9 // to make sure that the minimum length covers up to 5 digits
	l_max := array_max(l)
	println(chalk.fg(chalk.style('Confusion Matrix' +
		if result.repetitions > 1 { ' (values averaged over $result.repetitions repetitions):' } else { ':' },
		'underline'), 'blue'))
	mut padded_item := ''
	for i, rows in display_confusion_matrix {
		for j, item in rows {
			match true {
				i == 0 && j == 0 { // print first item in first row, ie 'predicted classes (columns)'
					print(chalk.fg('$item  ', 'red'))
				}
				i == 0 { // print column headers, ie classes
					padded_item = '${pad(l_max - item.len + 2)}' + item
					print(chalk.fg('$padded_item', 'red'))
				}
				i == 1 && j == 0 { // print 'actual classes' header
					padded_item = '${pad(6)}' + item
					print(chalk.fg('$padded_item', 'blue'))
				}
				j == 0 { // print first column (class names)
					padded_item = '${pad(27 - item.len)}' + item + '  '
					print(chalk.fg('$padded_item', 'blue'))
				}
				else { // print numeric values for each cell
					padded_item = '${pad(l_max - item.len + 2)}' + item
					print('$padded_item')
				}
			}
		}
		// carriage return at end of line
		println('')
	}
}

// show_expanded_explore_result
fn show_expanded_explore_result(result CrossVerifyResult, opts Options) ? {
	if result.pos_neg_classes[0] != '' {
		println('${opts.number_of_attributes[0]:10} ${get_show_bins(opts.bins)}  ${get_binary_stats_line(result.BinaryMetrics)}')
	} else {
		println('${opts.number_of_attributes[0]:10} ${get_show_bins(opts.bins)}')
		// show_multiple_classes_stats(get_metrics(result)?, result)?
	}
}

// show_explore_header
fn show_explore_header(results ExploreResult, settings DisplaySettings) {
	mut explore_type_string := ''
	if results.testfile_path == '' {
		explore_type_string = if results.folds == 0 { 'leave-one-out ' } else { '$results.folds-fold ' } + 'cross-validation' + if results.repetitions > 0 { '\n ($results.repetitions repetitions' + if results.random_pick { ', with random selection of instances)' } else { ')' }
		 } else { ''
		 }
	} else {
		explore_type_string = 'verification of "$results.testfile_path"'
	}
	println(chalk.fg(chalk.style('\nExplore $explore_type_string using classifiers from "$results.path"',
		'underline'), 'magenta'))
	if results.binning.lower == 0 {
		println('No continuous attributes, thus no binning')
	} else {
		println('Binning range for continuous attributes: from $results.binning.lower to $results.binning.upper with interval $results.binning.interval')
	}
	if results.uniform_bins {
		println('(same number of bins for all continous attributes)')
	}
	println('Missing values: ' + if results.exclude_flag { 'excluded' } else { 'included' })
	println(if results.weighting_flag { 'Weighting' } else { 'Not weighting' } +
		' nearest neighbor counts by class prevalences')
	println('Over attribute range from $results.start to $results.end by interval $results.att_interval')
	purge_string := if results.purge_flag { 'on' } else { 'off' }
	println('Purging of duplicate instances: $purge_string')
	if !settings.expanded_flag {
		println(chalk.fg(chalk.style('Attributes     Bins' +
			if results.purge_flag { '     Purged instances      (%)' } else { '' } +
			'  Matches  Nonmatches  Accuracy(%): Raw  Balanced', 'underline'), 'blue'))
	} else {
		if results.pos_neg_classes[0] != '' {
			println('A correct classification to "${results.pos_neg_classes[0]}" is a True Positive (TP);\nA correct classification to "${results.pos_neg_classes[1]}" is a True Negative (TN).')
			println('Note: for binary classification, balanced accuracy = (sensitivity + specificity) / 2')
			println(chalk.fg(chalk.style('Attributes    Bins' +
				if results.purge_flag { '      Purged instances      (%)' } else { '' } +
				"     TP    FP    TN    FN  Sens'y Spec'y PPV    NPV    F1 Score  Raw Acc'y  Bal'd",
				'underline'), 'blue'))
		} else {
			println(chalk.fg(chalk.style('Attributes     Bins' +
				if results.purge_flag { '     Purged instances      (%)' } else { '' },
				'underline'), 'blue'))
			println(chalk.fg(chalk.style('    Class                   Instances    True Positives    Precision    Recall    F1 Score',
				'underline'), 'blue'))
		}
	}
}

// show_explore_line displays on the console the results of each
// cross-validation or verification during an explore session.
fn show_explore_line(result CrossVerifyResult) ? {
	// println(result)
	// do nothing if neither the -s or the -e flag was set
	if result.show_flag || result.expanded_flag {
		mut total_count_avg := 0.0
		mut purged_count_avg := 0.0
		mut purged_percent := 0.0
		if result.purge_flag {
			total_count_avg = arrays.sum(result.prepurge_instances_counts_array) or {} / f64(result.prepurge_instances_counts_array.len)
			purged_count_avg = total_count_avg - arrays.sum(result.classifier_instances_counts) or {} / f64(result.classifier_instances_counts.len)
			purged_percent = 100 * purged_count_avg / total_count_avg
			// println('Average instances purged: ${purged_count_avg:10.1f} out of $total_count_avg (${purged_percent:6.2f}%)')
		}
		if !result.expanded_flag {
			accuracy_percent := (f32(result.correct_count) * 100 / result.labeled_classes.len)
			// instances_avg := arrays.sum(result.classifier_instances_counts) or {0} / f64(result.classifier_instances_counts.len)
			// instances_percent := 100.0 * instances_avg / f64(result.prepurge_instances_counts_array.len)
			metrics := get_metrics(result)?
			// println(result.prepurge_instances_counts_array.len)

			println('${result.attributes_used:10}  ${get_show_bins(result.bin_values)}' +
				if result.purge_flag {
				'${purged_count_avg:10.1f} out of $total_count_avg (${purged_percent:5.1f}%)'
			} else {
				''
			} +
				'  ${result.correct_count:7}  ${result.labeled_classes.len - result.correct_count:10}           ${accuracy_percent:7.2f}   ${metrics.balanced_accuracy * 100:7.2f}')
		} else {
			if result.pos_neg_classes[0] != '' {
				println('${result.attributes_used:10} ${get_show_bins(result.bin_values)}' + if result.purge_flag {
					' ${purged_count_avg:10.1f} out of $total_count_avg (${purged_percent:5.1f}%)'
				} else {
					''
				} + '  ${get_binary_stats_line(result.BinaryMetrics)}')
			} else {
				println('${result.attributes_used:10} ${get_show_bins(result.bin_values)}' + if result.purge_flag {
					' ${purged_count_avg:10.1f} out of $total_count_avg (${purged_percent:5.1f}%)'
				} else {
					''
				})
				// show_multiple_classes_stats(get_metrics(result)?, result)?
			}
		}
	}
}

// get_binary_stats_line
fn get_binary_stats_line(bm BinaryMetrics) string {
	return '${bm.t_p:5} ${bm.f_p:5} ${bm.t_n:5} ${bm.f_n:5}  ${bm.sens:5.3f}  ${bm.spec:5.3f}  ${bm.ppv:5.3f}  ${bm.npv:5.3f}  ${bm.f1_score:5.3f}     ${bm.raw_acc:6.2f}%  ${bm.balanced_accuracy_binary:6.2f}%'
}

// show_multiple_classes_stats
fn show_multiple_classes_stats(result CrossVerifyResult) ? {
	mut show_result := []string{}
	m := result.Metrics
	for i, class in result.class_counts.keys() {
		show_result << '    ${class:-21}       ${result.labeled_instances[class]:5}   ${result.correct_inferences[class]:5} (${f32(result.correct_inferences[class]) * 100 / result.labeled_instances[class]:6.2f}%)        ${m.precision[i]:5.3f}     ${m.recall[i]:5.3f}       ${m.f1_score[i]:5.3f}'
	}
	show_result << '        Totals                  ${result.total_count:5}   ${result.correct_count:5} (accuracy: raw:${f32(result.correct_count) * 100 / result.total_count:6.2f}% multiclass balanced:${result.balanced_accuracy * 100:6.2f}%)'
	for i, avg_type in m.avg_type {
		show_result << '${avg_type.title():18} Averages:                                   ${m.avg_precision[i]:5.3f}     ${m.avg_recall[i]:5.3f}       ${m.avg_f1_score[i]:5.3f}'
	}
	print_array(show_result)
}
