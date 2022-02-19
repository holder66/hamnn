// cross_validate.v
module hamnn

import strconv
import runtime
import rand

// cross_validate takes a dataset and performs n-fold cross-validation.
// ```sh
// Options (also see the Options struct):
// bins: range for binning or slicing of continuous attributes;
// uniform_bins: same number of bins for continuous attributes;
// number_of_attributes: range for attributes to include;
// exclude_flag: excludes missing values when ranking attributes;
// weighting_flag: rank attributes and count nearest neighbors accounting
// for class prevalences;
// folds: number of folds n to use for n-fold cross-validation (default
// is leave-one-out cross-validation);
// repetitions: number of times to repeat n-fold cross-validations;
// random-pick: choose instances randomly for n-fold cross-validations.
// Output options:
// show_flag: prints results to the console;
// expanded_flag: prints additional information to the console, including
// 		a confusion matrix.
// ```
pub fn cross_validate(ds Dataset, opts Options) CrossVerifyResult {
	// to sort out what is going on, run the test file with concurrency off.
	mut cross_opts := opts
	cross_opts.datafile_path = ds.path
	mut total_instances := ds.Class.class_values.len

	repeats := if opts.repetitions == 0 { 1 } else { opts.repetitions }
	// for each class, instantiate an entry in the confusion matrix map
	mut confusion_matrix_map := map[string]map[string]int{}
	for key1, _ in ds.class_counts {
		for key2, _ in ds.class_counts {
			confusion_matrix_map[key2][key1] = 0
		}
	}
	// instantiate a struct for the result
	mut cross_result := CrossVerifyResult{
		labeled_classes: ds.class_values
		class_counts: ds.class_counts
		pos_neg_classes: get_pos_neg_classes(ds.class_counts)
		confusion_matrix_map: confusion_matrix_map
	}
	mut repetition_result := CrossVerifyResult{}
	for rep in 0 .. repeats {
		// generate a pick list of indices
		mut pick_list := []int{}
		if opts.random_pick {
			mut n := 0
			for pick_list.len < total_instances {
				n = rand.int_in_range(0, total_instances)
				if n in pick_list {
					continue
				}
				pick_list << n
			}
		} else {
			for i in 0 .. total_instances {
				pick_list << i
			}
		}
		println(pick_list)
		repetition_result = do_repetition(pick_list, rep, ds, cross_opts)

		cross_result.inferred_classes << repetition_result.inferred_classes
		cross_result.actual_classes << repetition_result.actual_classes
	}
	cross_result = summarize_results(repeats, mut cross_result)
	// show_results(cross_result, cross_opts)
	if cross_opts.command == 'cross' && (cross_opts.show_flag || cross_opts.expanded_flag) {
		show_crossvalidation_result(cross_result, cross_opts)
	}
	return cross_result
}

// do_repetition
fn do_repetition(pick_list []int, rep int, ds Dataset, cross_opts Options) CrossVerifyResult {
	println('rep: $rep')
	mut fold_result := CrossVerifyResult{}
	// instantiate a struct for the result
	mut repetition_result := CrossVerifyResult{}
	// test if leave-one-out crossvalidation is requested
	folds := if cross_opts.folds == 0 { ds.class_values.len } else { cross_opts.folds }
	// if the concurrency flag is set
	if cross_opts.concurrency_flag {
		mut result_channel := chan CrossVerifyResult{cap: folds}
		// queue all work + the sentinel values:
		jobs := runtime.nr_jobs()
		mut work_channel := chan int{cap: folds + jobs}
		for i in 0 .. folds {
			work_channel <- i
		}
		for _ in 0 .. jobs {
			work_channel <- -1
		}
		// start a thread pool to do the work:
		mut tpool := []thread{}
		for _ in 0 .. jobs {
			tpool << go option_worker(work_channel, result_channel, pick_list, folds,
				ds, cross_opts)
		}
		tpool.wait()
		//
		for _ in 0 .. folds {
			fold_result = <-result_channel
			repetition_result.inferred_classes << fold_result.inferred_classes
			repetition_result.actual_classes << fold_result.labeled_classes
		}
	} else {
		// for each fold
		for current_fold in 0 .. folds {
			fold_result = do_one_fold(pick_list, current_fold, folds, ds, cross_opts)
			repetition_result.inferred_classes << fold_result.inferred_classes
			repetition_result.actual_classes << fold_result.labeled_classes
		}
	}
	return repetition_result
}

// summarize_results
fn summarize_results(repeats int, mut result CrossVerifyResult) CrossVerifyResult {
	mut inferred := ''
	for i, actual in result.actual_classes {
		inferred = result.inferred_classes[i]
		result.labeled_instances[actual] += 1
		result.total_count += 1
		result.confusion_matrix_map[actual][inferred] += 1
		if actual == inferred {
			result.correct_inferences[actual] += 1
			result.correct_count += 1
		} else {
			result.wrong_inferences[inferred] += 1
			result.incorrect_inferences[actual] += 1
			result.incorrects_count += 1
			result.wrong_count += 1
		}
	}
	if repeats > 1 {
		result.correct_count /= repeats
		result.incorrects_count /= repeats
		result.wrong_count /= repeats
		result.total_count /= repeats

		for _, mut v in result.labeled_instances {
			v /= repeats
		}
		for _, mut v in result.correct_inferences {
			v /= repeats
		}
		for _, mut v in result.incorrect_inferences {
			v /= repeats
		}
		for _, mut v in result.wrong_inferences {
			v /= repeats
		}

		for _, mut m in result.confusion_matrix_map {
			for _, mut v in m {
				v /= repeats
			}
		}
	}
	// collect confusion matrix rows into a matrix
	mut header_row := ['Predicted Classes (columns)']
	mut data_row := []string{}
	for key, _ in result.confusion_matrix_map {
		header_row << key
		data_row = [key]
		for _, value in result.confusion_matrix_map[key] {
			data_row << '$value'
		}
		result.confusion_matrix << data_row
	}
	result.confusion_matrix.prepend(['Actual Classes (rows)'])
	result.confusion_matrix.prepend(header_row)

	return result
}

// div_map
fn div_map(n int, mut m map[string]int) map[string]int {
	for _, mut a in m {
		a /= n
	}
	return m
}

// do_one_fold
fn do_one_fold(pick_list []int, current_fold int, folds int, ds Dataset, cross_opts Options) CrossVerifyResult {
	mut byte_values_array := [][]byte{}
	// partition the dataset into a partial dataset and a fold
	part_ds, fold := partition(pick_list, current_fold, folds, ds, cross_opts)
	println('fold: $fold')
	mut fold_result := CrossVerifyResult{
		labeled_classes: fold.class_values
	}
	part_cl := make_classifier(part_ds, cross_opts)
	// println('part_cl.attribute_ordering: $part_cl.attribute_ordering')
	// for each attribute in the trained partition classifier
	for attr in part_cl.attribute_ordering {
		// get the index of the corresponding attribute in the fold
		j := fold.attribute_names.index(attr)
		// println('attr, j, fold.data[j]: $attr $j ${fold.data[j]}')
		// create byte_values for the fold data
		byte_values_array << process_fold_data(part_cl.trained_attributes[attr], fold.data[j])
	}
	// println('byte_values_array: $byte_values_array')
	fold_instances := transpose(byte_values_array)

	// println('fold_instances: $fold_instances')
	// for each class, instantiate an entry in the class table for the result
	// note that this needs to use the classes in the partition portion, not
	// the fold, so that wrong inferences get recorded properly.
	mut confusion_matrix_row := map[string]int{}
	// for each class, instantiate an entry in the confusion matrix row
	for key, _ in ds.Class.class_counts {
		confusion_matrix_row[key] = 0
	}
	fold_result = classify_in_cross(part_cl, fold_instances, mut fold_result, cross_opts)
	// println('fold_result: $fold_result')
	return fold_result
}

// process_fold_data
fn process_fold_data(part_attr TrainedAttribute, fold_data []string) []byte {
	// println('fold_data: $fold_data')
	mut byte_vals := []byte{cap: fold_data.len}

	// for a continuous attribute
	if part_attr.attribute_type == 'C' {
		values := fold_data.map(f32(strconv.atof_quick(it)))
		byte_vals << bin_values_array(values, part_attr.minimum, part_attr.maximum, part_attr.bins)
	} else {
		byte_vals << fold_data.map(byte(part_attr.translation_table[it]))
	}
	return byte_vals
}

// option_worker
fn option_worker(work_channel chan int, result_channel chan CrossVerifyResult, pick_list []int, folds int, ds Dataset, opts Options) {
	for {
		mut current_fold := <-work_channel
		if current_fold < 0 {
			break
		}
		result_channel <- do_one_fold(pick_list, current_fold, folds, ds, opts)
	}
}

// classify_in_cross classifies each instance in an array, and
// returns the results of the classification.
fn classify_in_cross(cl Classifier, test_instances [][]byte, mut result CrossVerifyResult, opts Options) CrossVerifyResult {
	// for each instance in the test data, perform a classification
	mut inferred_class := ''
	for i, test_instance in test_instances {
		inferred_class = classify_instance(i, cl, test_instance, opts).inferred_class
		result.inferred_classes << inferred_class
		result.actual_classes << result.labeled_classes[i]
	}
	if opts.verbose_flag && opts.command == 'verify' {
		println('result in classify_to_verify(): $result')
	}
	result = summarize_results(1, mut result)
	if opts.verbose_flag && opts.command == 'verify' {
		println('summarize_result: $result')
	}
	return result
}
