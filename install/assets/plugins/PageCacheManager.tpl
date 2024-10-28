//<?php
/**
 * PageCacheManager
 *
 * Customize EVO cache deletion and manage cache files efficiently across documents.
 *
 * @category    plugin
 * @version     1.0RC
 * @license     http://www.gnu.org/copyleft/gpl.html GNU Public License (GPL)
 * @internal    @properties &alwaysDelete_docs=Always clear cache of these Documents by id (comma separated);string; &alwaysDelete_templates=Always clear cache of these Documents by Template id (comma separated);string; &exclude_docs=Exclude Documents by id (comma separated);string; &exclude_templates=Exclude Templates by id (comma separated);string; &Debug= Enable debug messages and errors logs:;list;yes,no;no
 * @internal    @events OnDocFormRender,OnDocFormSave,OnDocFormDelete
 * @internal    @modx_category Cache Management
 * @internal    @legacy_names PageCacheManager
 * @internal    @installset base, sample
 */

global $modx;

// Retrieve the configuration parameters
$alwaysDelete_docs = explode(',', $alwaysDelete_docs);
$alwaysDelete_templates = explode(',', $alwaysDelete_templates);
$exclude_docs = explode(',', $exclude_docs);
$exclude_templates = explode(',', $exclude_templates);

$template_id = $modx->db->getValue($modx->db->select('template', $modx->getFullTableName('site_content'), "id=$id"));

// OnDocFormRender event: disables the cache checkbox if documents and templates are not excluded
if ($modx->event->name == 'OnDocFormRender') {
    if (!in_array($id, $exclude_docs) && !in_array($template_id, $exclude_templates)) {
        $output = "<script>";
        $output .= 'jQuery(document).ready(function($) {';
        $output .= '    $("input[name=\'syncsite\']").val(0);';
        $output .= '    $("input[name=\'syncsitecheck\']").prop("checked", false);';
        $output .= '});';
        $output .= "</script>";
        $modx->event->output($output);
    }
}

// OnDocFormSave/OnDocFormDelete event: Clears the cache for the current document and those specified in alwaysDelete_docs/templates
if ($modx->event->name == 'OnDocFormSave' || $modx->event->name == 'OnDocFormDelete') {
    if (!in_array($id, $exclude_docs) && !in_array($template_id, $exclude_templates)) {
        // List of documents whose cache should be cleared (including the current document)
        $doc_ids_to_delete = array_merge([$id], $alwaysDelete_docs);

        // Add documents associated with the templates specified in always Delete templates
        if (!empty($alwaysDelete_templates)) {
            $template_docs = $modx->db->getColumn('id', $modx->db->select(
                'id',
                $modx->getFullTableName('site_content'),
                'template IN (' . implode(',', array_map('intval', $alwaysDelete_templates)) . ')'
            ));
            $doc_ids_to_delete = array_merge($doc_ids_to_delete, $template_docs);
        }

        // Remove any duplicates
        $doc_ids_to_delete = array_unique($doc_ids_to_delete);

        // Initialize the log lists
        $deleted_files = [];
        $additional_deleted_ids = [];

        foreach ($doc_ids_to_delete as $doc_id) {
            if ($doc_id == 1) {
                // Specific handling for the document with ID=1
                $file_path = MODX_BASE_PATH . $modx->getCacheFolder() . 'docid_1.pageCache.php';
                if (file_exists($file_path) && is_writable($file_path)) {
                    unlink($file_path);
                    if ($Debug == 'yes') {
                        // Add the file to the deleted list
                        if ($doc_id == $id) {
                            $deleted_files[] = 'docid_1.pageCache.php (ID=1)';
                        } else {
                            $additional_deleted_ids[] = $doc_id;
                        }
                    }
                }
            } else {
                // Clear cache for other documents with pattern
                $cache_folder = MODX_BASE_PATH . $modx->getCacheFolder();
                $pattern = '/^docid_' . preg_quote($doc_id, '/') . '_.*$/';
                $files = scandir($cache_folder);

                if ($files !== false) {
                    foreach ($files as $file) {
                        if (preg_match($pattern, $file)) {
                            $file_path = $cache_folder . $file;
                            if (file_exists($file_path) && is_writable($file_path)) {
                                unlink($file_path);
                                if ($Debug == 'yes') {
                                    if ($doc_id == $id) {
                                        $deleted_files[] = $file . ' (ID=' . $doc_id . ')';
                                    } else {
                                        $additional_deleted_ids[] = $doc_id;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Final log
        if ($Debug == 'yes') {
            // Confirm deletion of current document cache
            if (!empty($deleted_files)) {
                $modx->logEvent(0, 1, 'PageCacheManager - Cache deleted for current document ID ' . $id . ': ' . implode(', ', $deleted_files), 'PageCacheManager ID ' . $id . '');
            }
            // Additional Document Log
            if (!empty($additional_deleted_ids)) {
                $modx->logEvent(0, 1, 'PageCacheManager - Additional documents cleared: ' . implode(', ', array_unique($additional_deleted_ids)), 'PageCacheManager Additional documents');
            }
        }
    }
}