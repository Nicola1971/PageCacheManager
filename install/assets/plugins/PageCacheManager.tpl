//<?php
/**
 * PageCacheManager
 *
 * Customize EVO cache deletion and manage cache files efficiently across documents.
 *
 * @category    plugin
 * @version     2.0RC
 * @license     http://www.gnu.org/copyleft/gpl.html GNU Public License (GPL)
 * @internal    @properties &alwaysDelete_docs=Always clear cache of these Documents by id (comma separated);string; &alwaysDelete_templates=Always clear cache of these Documents by Template id (comma separated);string; &exclude_docs=Exclude Documents by id (comma separated);string; &exclude_templates=Exclude Templates by id (comma separated);string; &Debug= Enable debug messages and errors logs:;list;yes,no;no
 * @internal    @events OnDocFormRender,OnDocFormSave,OnDocFormDelete
 * @internal    @modx_category Cache Management
 * @internal    @legacy_names PageCacheManager
 * @internal    @installset base, sample
 */

global $modx;

// Retrieve configuration parameters
$alwaysDelete_docs = explode(',', $alwaysDelete_docs);
$alwaysDelete_templates = explode(',', $alwaysDelete_templates);
$exclude_docs = explode(',', $exclude_docs);
$exclude_templates = explode(',', $exclude_templates);
$debug_enabled = ($Debug === 'yes');

$template_id = $modx->db->getValue($modx->db->select('template', $modx->getFullTableName('site_content'), "id=$id"));

// Event OnDocFormRender: disables cache checkbox if document/template is not excluded
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

// Event OnDocFormSave/OnDocFormDelete: Clears cache for the current document and specified ones in alwaysDelete_docs/templates
if ($modx->event->name == 'OnDocFormSave' || $modx->event->name == 'OnDocFormDelete') {
    if (!in_array($id, $exclude_docs) && !in_array($template_id, $exclude_templates)) {
        // Documents to delete cache (including current document)
        $doc_ids_to_delete = array_merge([$id], $alwaysDelete_docs);

        // Add documents associated with specified templates
        if (!empty($alwaysDelete_templates)) {
            $template_docs = $modx->db->getColumn('id', $modx->db->select(
                'id',
                $modx->getFullTableName('site_content'),
                'template IN (' . implode(',', array_map('intval', $alwaysDelete_templates)) . ')'
            ));
            $doc_ids_to_delete = array_merge($doc_ids_to_delete, $template_docs);
        }

        // Remove duplicates and set up log arrays
        $doc_ids_to_delete = array_unique($doc_ids_to_delete);
        $additional_deleted_ids = array_diff($doc_ids_to_delete, [$id]);

        // Clear cache for each document ID
        foreach ($doc_ids_to_delete as $doc_id) {
            $modx->clearCache($doc_id);
        }

        // Logging
        if ($debug_enabled) {
            // Confirm cache deletion for current document
            $modx->logEvent(0, 1, "PageCacheManager - Cache cleared for current document ID={$id}", 'PageCacheManager ID ' . $id . '');
            
            // Log additional documents if any
            if (!empty($additional_deleted_ids)) {
                $modx->logEvent(0, 1, 'PageCacheManager - Additional documents cleared: ' . implode(', ', $additional_deleted_ids), 'PageCacheManager Additional documents');
            }
        }
    }
}