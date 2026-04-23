#!/usr/bin/env bash

set -euo pipefail

IMAGE="${1:-martialblog/limesurvey:6-apache}"
OUTPUT_PATCH="${2:-$(cd "$(dirname "$0")/.." && pwd)/patches/add_functions.patch}"
TARGET_REL="application/helpers/remotecontrol/remotecontrol_handle.php"
TARGET_IN_CONTAINER="/var/www/html/${TARGET_REL}"

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORK_DIR="$(mktemp -d)"
CONTAINER_ID=""

cleanup() {
  if [[ -n "$CONTAINER_ID" ]]; then
    docker rm -f "$CONTAINER_ID" >/dev/null 2>&1 || true
  fi
  rm -rf "$WORK_DIR"
}

trap cleanup EXIT

mkdir -p "$(dirname "$OUTPUT_PATCH")"

CONTAINER_ID="$(docker create "$IMAGE")"
docker cp "$CONTAINER_ID:$TARGET_IN_CONTAINER" "$WORK_DIR/original.php"
cp "$WORK_DIR/original.php" "$WORK_DIR/modified.php"

if ! grep -q 'public function get_session_key' "$WORK_DIR/original.php"; then
  echo "Could not find get_session_key anchor in $TARGET_REL" >&2
  exit 1
fi

if grep -q 'public function update_plugin_settings' "$WORK_DIR/original.php"; then
  echo "The selected image already contains update_plugin_settings; no patch generated." >&2
  : > "$OUTPUT_PATCH"
  exit 0
fi

read -r -d '' INSERT_BLOCK <<'EOF' || true
    /**
    * RPC method: update_plugin_settings
    *
    * @access public
    * @param string $sSessionKey
    * @param string $sPluginName
    * @param int    $iSurveyId      Use 0 for global settings
    * @param array  $aSettings      key=>value pairs
    * @return array                ['status'=>'OK'] or throws CHttpException(400, ...)
    */
    public function update_plugin_settings($sSessionKey, $sPluginName, $iSurveyId, $aSettings)
    {
        if (!$this->_checkSessionKey($sSessionKey)) {
            return array('status' => self::INVALID_SESSION_KEY);
        }

        /** @var PluginManager $pm */
        $pm = Yii::app()->pluginManager;
        $plugin = $pm->loadPlugin($sPluginName);

        if ($plugin === null) {
            throw new CHttpException(500, "Plugin '$sPluginName' not found or not loaded correctly.");
        }

        try {
            if ((int) $iSurveyId > 0) {
                if (!method_exists($plugin, 'setSurveySettings')) {
                    throw new CHttpException(500, "Function setSurveySettings does not exist for plugin '$sPluginName'.");
                }
                $plugin->setSurveySettings((int) $iSurveyId, $aSettings);
            } else {
                if (!method_exists($plugin, 'setGlobalSettings')) {
                    throw new CHttpException(500, "Function setGlobalSettings does not exist for plugin '$sPluginName'.");
                }
                $plugin->setGlobalSettings($aSettings);
            }
        } catch (Exception $e) {
            throw new CHttpException(500, "Could not save plugin settings: " . $e->getMessage());
        }

        return array('status' => 'OK');
    }

    /**
    * RPC Routine to export a survey structure (LSS).
    *
    * @access public
    * @param string $sSessionKey Auth credentials
    * @param int $iSurveyID_org Id of the survey
    * @return string|array in case of success : Base64 encoded string of the .lss file. On failure array with error information.
    */
    public function export_survey_structure($sSessionKey, $iSurveyID_org)
    {
        $iSurveyID = (int) $iSurveyID_org;
        if (!$this->_checkSessionKey($sSessionKey)) {
            return array('status' => self::INVALID_SESSION_KEY);
        }

        $aData['bFailed'] = false;
        if (!$iSurveyID) {
            $aData['sErrorMessage'] = 'No survey ID has been provided. Cannot export survey';
            $aData['bFailed'] = true;
        } elseif (!Survey::model()->findByPk($iSurveyID)) {
            $aData['sErrorMessage'] = 'Invalid survey ID';
            $aData['bFailed'] = true;
        } elseif (!Permission::model()->hasSurveyPermission($iSurveyID, 'surveycontent', 'export')) {
            $aData['sErrorMessage'] = "You don't have sufficient permissions.";
            $aData['bFailed'] = true;
        } else {
            $aExcludes = array();
            $aExcludes['dates'] = true;
            Yii::app()->loadHelper('export');
            $exportsurveystructuredata = surveyGetXMLData($iSurveyID, $aExcludes);
            if ($exportsurveystructuredata) {
                $sResult = $exportsurveystructuredata;
            } else {
                $aData['sErrorMessage'] = 'Survey export returned no data';
                $aData['bFailed'] = true;
            }
        }

        if ($aData['bFailed']) {
            return array('status' => 'Export failed', 'error' => $aData['sErrorMessage']);
        }

        return base64_encode($sResult);
    }

EOF

printf '%s\n\n' "$INSERT_BLOCK" > "$WORK_DIR/insert_block.php"

INSERT_FILE="$WORK_DIR/insert_block.php" perl -0pe '
    BEGIN {
        local $/;
        open my $fh, "<", $ENV{INSERT_FILE} or die "Could not open insert block\n";
        $insert = <$fh>;
        close $fh;
    }

    s/^(\s*\/\*\*\n\s*\* Create and return a session key\.)/$insert$1/ms
        or die "Could not locate insertion point before get_session_key docblock\n";
' "$WORK_DIR/original.php" > "$WORK_DIR/modified.php"

if cmp -s "$WORK_DIR/original.php" "$WORK_DIR/modified.php"; then
  echo "No changes were made while generating the patch." >&2
  : > "$OUTPUT_PATCH"
  exit 1
fi

diff -u \
  --label "${TARGET_REL}.orig" \
  --label "$TARGET_REL" \
  "$WORK_DIR/original.php" \
  "$WORK_DIR/modified.php" > "$OUTPUT_PATCH" || true

echo "Generated patch: $OUTPUT_PATCH"
