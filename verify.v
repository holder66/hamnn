// verify.v
/*
Given a classifier and a verification dataset, classifies each instance
  of the verification_set on the trained classifier; returns metrics
  comparing the predicted classes to the assigned classes.*/
module hamnn

import runtime

// verify classifies each instance of a verification datafile against
// a trained Classifier; returns metrics comparing the inferred classes
// to the labeled (assigned) classes of the verification datafile.
pub fn verify(cl Classifier, opts Options) VerifyResult {
	// load the testfile as a Dataset struct
	mut test_ds := load_file(opts.testfile_path)
	// instantiate a struct for the result
	mut verify_result := VerifyResult{
		labeled_classes: test_ds.Class.class_values
		pos_neg_classes: get_pos_neg_classes(test_ds.class_counts)
	}
	mut confusion_matrix_row := map[string]int{}
	// for each class, instantiate an entry in the confusion matrix row
	for key, _ in test_ds.Class.class_counts {
		confusion_matrix_row[key] = 0
	}
	// for each class, instantiate an entry in the class table
	for key, value in test_ds.Class.class_counts {
		verify_result.class_table[key] = ResultForClass{
			labeled_instances: value
			confusion_matrix_row: confusion_matrix_row.clone()
		}
	}
	// massage each instance in the test dataset according to the
	// attribute parameters in the classifier
	test_instances := generate_test_instances_array(cl, test_ds)
	// for the instances in the test data, perform classifications
	verify_result = classify_to_verify(cl, test_instances, mut verify_result, opts)
	show_verify(verify_result, opts)
	if opts.verbose_flag && opts.command == 'verify' {
		println('verify_result.class_table in verify: $verify_result.class_table')
	}
	return verify_result
}

// generate_test_instances_array
fn generate_test_instances_array(cl Classifier, test_ds Dataset) [][]byte {
	// for each usable attribute in cl, massage the equivalent test_ds attribute
	mut test_binned_values := []int{}
	mut test_attr_binned_values := [][]byte{}
	mut test_index := 0
	for attr in cl.attribute_ordering {
		// get an index into this attribute in test_ds
		for j, value in test_ds.attribute_names {
			if value == attr {
				test_index = j
			}
		}
		if cl.trained_attributes[attr].attribute_type == 'C' {
			test_binned_values = discretize_attribute<f32>(test_ds.useful_continuous_attributes[test_index],
				cl.trained_attributes[attr].minimum, cl.trained_attributes[attr].maximum,
				cl.trained_attributes[attr].bins)
		} else { // ie for discrete attributes
			test_binned_values = test_ds.useful_discrete_attributes[test_index].map(cl.trained_attributes[attr].translation_table[it])
		}
		test_attr_binned_values << test_binned_values.map(byte(it))
	}
	return transpose(test_attr_binned_values)
}

// option_worker_verify
fn option_worker_verify(work_channel chan int, result_channel chan ClassifyResult, cl Classifier, test_instances [][]byte, labeled_classes []string, opts Options) {
	mut index := <-work_channel
	mut classify_result := classify_instance(cl, test_instances[index], opts)
	classify_result.labeled_class = labeled_classes[index]
	result_channel <- classify_result
	// dump(result_channel)
	return
}

// classify_to_verify classifies each instance in an array, and
// returns the results of the classification.
fn classify_to_verify(cl Classifier, test_instances [][]byte, mut result VerifyResult, opts Options) VerifyResult {
	// for each instance in the test data, perform a classification
	mut inferred_class := ''
	mut classify_result := ClassifyResult{}
	if opts.concurrency_flag {
		mut work_channel := chan int{cap: runtime.nr_jobs()}
		mut result_channel := chan ClassifyResult{cap: test_instances.len}
		for i, _ in test_instances {
			work_channel <- i
			go option_worker_verify(work_channel, result_channel, cl, test_instances,
				result.labeled_classes, opts)
		}
		for _ in test_instances {
			classify_result = <-result_channel
			if classify_result.inferred_class == classify_result.labeled_class {
				result.class_table[classify_result.inferred_class].correct_inferences += 1
			} else {
				result.class_table[classify_result.inferred_class].wrong_inferences += 1
			}
			// update confusion matrix row
			result.class_table[classify_result.labeled_class].confusion_matrix_row[classify_result.inferred_class] += 1
		}
	} else {
		for i, test_instance in test_instances {
			inferred_class = classify_instance(cl, test_instance, opts).inferred_class
			if inferred_class == result.labeled_classes[i] {
				result.class_table[result.labeled_classes[i]].correct_inferences += 1
			} else {
				result.class_table[inferred_class].wrong_inferences += 1
			}
			// update confusion matrix row
			result.class_table[result.labeled_classes[i]].confusion_matrix_row[inferred_class] += 1
		}
	}
	if opts.verbose_flag && opts.command == 'verify' {
		// println('result.class_table in verify: $result.class_table')
	}

	return summarize_results(mut result)
}

// summarize_results
fn summarize_results(mut result VerifyResult) VerifyResult {
	for _, mut value in result.class_table {
		value.missed_inferences = value.labeled_instances - value.correct_inferences
		result.correct_count += value.correct_inferences
		result.total_count += value.labeled_instances
		result.misses_count += value.missed_inferences
		result.wrong_count += value.wrong_inferences
	}
	// collect confusion matrix rows into a matrix
	mut header_row := ['Predicted Classes (columns)']
	mut data_row := []string{}
	for key, value in result.class_table {
		header_row << key
		data_row = [key]
		for _, value2 in value.confusion_matrix_row {
			data_row << '$value2'
		}
		result.confusion_matrix << data_row
	}
	result.confusion_matrix.prepend(['Actual Classes (rows)'])
	result.confusion_matrix.prepend(header_row)
	return result
}
