/**
 * HierarchicalRecordCreator
 *
 * A generic Flow Invocable Action that creates up to 3 levels of related records
 * (parent → child → grandchild) in a single atomic Apex transaction.
 *
 * Solves the Screen Flow limitation where DML is deferred until a commit point
 * (Screen element or flow end), making record IDs unavailable for populating
 * lookup fields on subsequent records.
 *
 * Compatible with:
 *   - LWR Digital Experience Sites (no Aura dependency)
 *   - Aura Digital Experience Sites
 *   - Internal Lightning Apps
 *   - Screen Flows, Autolaunched Flows, Record-Triggered Flows
 *
 * Usage: Add as an Action element in Flow Builder → search "Create Hierarchical Records"
 *
 * @author  Redpoint Ascent
 * @version 1.0
 * @since   2026-02-16
 * @see     https://github.com/redpointascent/flow-hierarchical-record-creator
 */
public with sharing class HierarchicalRecordCreator {
  /**
   * Request wrapper — one instance per Flow Action invocation.
   * All inputs are configured in the Flow Action element's property editor.
   */
  public class Request {
    @InvocableVariable(
      label='Parent Records'
      description='Collection of Level 1 (parent) sObject records to insert.'
      required=true
    )
    public List<SObject> parentRecords;

    @InvocableVariable(
      label='Child Records'
      description='Collection of Level 2 (child) sObject records to insert. Optional.'
    )
    public List<SObject> childRecords;

    @InvocableVariable(
      label='Child Lookup Field API Name'
      description='API name of the lookup field on the child object that references the parent (e.g. AccountId, Parent_Order__c). Required if Child Records is provided.'
    )
    public String childLookupField;

    @InvocableVariable(
      label='Child-to-Parent Index Map'
      description='Parallel list to Child Records. Each integer is the 0-based index of the parent record that the child belongs to. Required if Child Records is provided and field-based matching is not used.'
    )
    public List<Integer> childParentIndex;

    @InvocableVariable(
      label='Child Match Field'
      description='API name of the field on child records containing the match key value. Used for field-based matching as an alternative to the index map. Mutually exclusive with childParentIndex.'
    )
    public String childMatchField;

    @InvocableVariable(
      label='Parent Match Field'
      description='API name of the field on parent records containing the unique match key value. Required when childMatchField is provided. Each parent must have a unique, non-blank value.'
    )
    public String parentMatchField;

    @InvocableVariable(
      label='Grandchild Records'
      description='Collection of Level 3 (grandchild) sObject records to insert. Optional.'
    )
    public List<SObject> grandchildRecords;

    @InvocableVariable(
      label='Grandchild Lookup Field API Name'
      description='API name of the lookup field on the grandchild object that references the child (e.g. ContactId, Order_Line__c). Required if Grandchild Records is provided.'
    )
    public String grandchildLookupField;

    @InvocableVariable(
      label='Grandchild-to-Child Index Map'
      description='Parallel list to Grandchild Records. Each integer is the 0-based index of the child record that the grandchild belongs to. Required if Grandchild Records is provided and field-based matching is not used.'
    )
    public List<Integer> grandchildParentIndex;

    @InvocableVariable(
      label='Grandchild Match Field'
      description='API name of the field on grandchild records containing the match key value. Used for field-based matching as an alternative to the grandchild index map. Mutually exclusive with grandchildParentIndex.'
    )
    public String grandchildMatchField;

    @InvocableVariable(
      label='Grandchild Parent Match Field'
      description='API name of the field on child records containing the unique match key value for grandchild matching. Required when grandchildMatchField is provided.'
    )
    public String grandchildParentMatchField;
  }

  /**
   * Response wrapper — returned to the Flow after execution.
   */
  public class Response {
    @InvocableVariable(
      label='Parent Record IDs'
      description='IDs of inserted parent records, in the same order as the input collection.'
    )
    public List<Id> parentIds;

    @InvocableVariable(
      label='Child Record IDs'
      description='IDs of inserted child records, in the same order as the input collection.'
    )
    public List<Id> childIds;

    @InvocableVariable(
      label='Grandchild Record IDs'
      description='IDs of inserted grandchild records, in the same order as the input collection.'
    )
    public List<Id> grandchildIds;

    @InvocableVariable(
      label='Success'
      description='True if all records were created successfully.'
    )
    public Boolean isSuccess;

    @InvocableVariable(
      label='Error Message'
      description='Populated with exception details if an error occurred. Empty on success.'
    )
    public String errorMessage;
  }

  /**
   * Main invocable entry point. Called by Flow Builder as an Action element.
   *
   * Inserts up to 3 levels of records in a single transaction. If any insert
   * fails, the entire transaction is rolled back automatically by the Apex runtime.
   * The exception propagates to the Flow's Fault connector.
   *
   * @param requests List of Request objects (one per Flow Action invocation)
   * @return List of Response objects with inserted record IDs
   */
  @InvocableMethod(
    label='Create Hierarchical Records'
    description='Creates up to 3 levels of related records (parent → child → grandchild) in a single atomic transaction. Lookup fields are automatically populated between levels.'
    category='Record Management'
  )
  public static List<Response> createRecords(List<Request> requests) {
    List<Response> responses = new List<Response>();

    for (Request req : requests) {
      Response res = new Response();
      res.parentIds = new List<Id>();
      res.childIds = new List<Id>();
      res.grandchildIds = new List<Id>();
      res.isSuccess = false;
      res.errorMessage = '';

      Savepoint sp = Database.setSavepoint();
      try {
        // --- Validation ---
        validateInputs(req);

        // --- Level 1: Parents ---
        insert req.parentRecords;
        for (SObject parent : req.parentRecords) {
          res.parentIds.add(parent.Id);
        }

        // --- Level 2: Children ---
        if (hasRecords(req.childRecords)) {
          if (usesChildFieldMatch(req)) {
            wireChildLookupsByMatchField(
              req.childRecords,
              req.childLookupField,
              req.childMatchField,
              req.parentMatchField,
              req.parentRecords
            );
          } else {
            wireChildLookups(
              req.childRecords,
              req.childLookupField,
              req.childParentIndex,
              req.parentRecords
            );
          }
          insert req.childRecords;
          for (SObject child : req.childRecords) {
            res.childIds.add(child.Id);
          }
        }

        // --- Level 3: Grandchildren ---
        if (hasRecords(req.grandchildRecords)) {
          if (usesGrandchildFieldMatch(req)) {
            wireChildLookupsByMatchField(
              req.grandchildRecords,
              req.grandchildLookupField,
              req.grandchildMatchField,
              req.grandchildParentMatchField,
              req.childRecords
            );
          } else {
            wireChildLookups(
              req.grandchildRecords,
              req.grandchildLookupField,
              req.grandchildParentIndex,
              req.childRecords
            );
          }
          insert req.grandchildRecords;
          for (SObject grandchild : req.grandchildRecords) {
            res.grandchildIds.add(grandchild.Id);
          }
        }

        res.isSuccess = true;
      } catch (Exception ex) {
        // Explicit rollback ensures all DML in this invocation is undone,
        // regardless of calling context (Flow, test, direct Apex).
        Database.rollback(sp);
        throw ex;
      }

      responses.add(res);
    }

    return responses;
  }

  // =========================================================================
  // Private helpers
  // =========================================================================

  /**
   * Validates all inputs before any DML occurs.
   * Throws IllegalArgumentException with a descriptive message on any violation.
   */
  private static void validateInputs(Request req) {
    // Parent records are required
    if (!hasRecords(req.parentRecords)) {
      throw new IllegalArgumentException(
        'HierarchicalRecordCreator: parentRecords is required and must not be empty.'
      );
    }

    // If children provided, lookup field and either index map or match fields are required
    if (hasRecords(req.childRecords)) {
      if (String.isBlank(req.childLookupField)) {
        throw new IllegalArgumentException(
          'HierarchicalRecordCreator: childLookupField is required when childRecords is provided.'
        );
      }

      Boolean hasIndex =
        req.childParentIndex != null && !req.childParentIndex.isEmpty();
      Boolean hasFieldMatch = usesChildFieldMatch(req);

      // Mutual exclusivity
      if (hasIndex && hasFieldMatch) {
        throw new IllegalArgumentException(
          'HierarchicalRecordCreator: Cannot use both childParentIndex and field-based matching (childMatchField/parentMatchField) at the same time. Use one or the other.'
        );
      }

      // Neither provided
      if (!hasIndex && !hasFieldMatch) {
        throw new IllegalArgumentException(
          'HierarchicalRecordCreator: childParentIndex or field-based matching (childMatchField + parentMatchField) is required when childRecords is provided.'
        );
      }

      if (hasFieldMatch) {
        // Both match fields must be provided as a pair
        if (
          String.isBlank(req.childMatchField) ||
          String.isBlank(req.parentMatchField)
        ) {
          throw new IllegalArgumentException(
            'HierarchicalRecordCreator: Both childMatchField and parentMatchField must be provided together for field-based matching.'
          );
        }
        validateParentMatchFieldValues(
          req.parentRecords,
          req.parentMatchField,
          'parentMatchField'
        );
        Set<String> parentKeys = collectMatchKeys(
          req.parentRecords,
          req.parentMatchField
        );
        validateChildMatchFieldValues(
          req.childRecords,
          req.childMatchField,
          'childMatchField',
          parentKeys
        );
      } else {
        // Index mode — existing validation
        if (req.childRecords.size() != req.childParentIndex.size()) {
          throw new IllegalArgumentException(
            'HierarchicalRecordCreator: childRecords (' +
              req.childRecords.size() +
              ') and childParentIndex (' +
              req.childParentIndex.size() +
              ') must be the same size.'
          );
        }
        validateIndexBounds(
          req.childParentIndex,
          req.parentRecords.size(),
          'childParentIndex',
          'parentRecords'
        );
      }
    }

    // Grandchildren require children
    if (hasRecords(req.grandchildRecords) && !hasRecords(req.childRecords)) {
      throw new IllegalArgumentException(
        'HierarchicalRecordCreator: grandchildRecords requires childRecords to also be provided.'
      );
    }

    // If grandchildren provided, lookup field and either index map or match fields are required
    if (hasRecords(req.grandchildRecords)) {
      if (String.isBlank(req.grandchildLookupField)) {
        throw new IllegalArgumentException(
          'HierarchicalRecordCreator: grandchildLookupField is required when grandchildRecords is provided.'
        );
      }

      Boolean hasGcIndex =
        req.grandchildParentIndex != null &&
        !req.grandchildParentIndex.isEmpty();
      Boolean hasGcFieldMatch = usesGrandchildFieldMatch(req);

      // Mutual exclusivity
      if (hasGcIndex && hasGcFieldMatch) {
        throw new IllegalArgumentException(
          'HierarchicalRecordCreator: Cannot use both grandchildParentIndex and field-based matching (grandchildMatchField/grandchildParentMatchField) at the same time. Use one or the other.'
        );
      }

      // Neither provided
      if (!hasGcIndex && !hasGcFieldMatch) {
        throw new IllegalArgumentException(
          'HierarchicalRecordCreator: grandchildParentIndex or field-based matching (grandchildMatchField + grandchildParentMatchField) is required when grandchildRecords is provided.'
        );
      }

      if (hasGcFieldMatch) {
        // Both match fields must be provided as a pair
        if (
          String.isBlank(req.grandchildMatchField) ||
          String.isBlank(req.grandchildParentMatchField)
        ) {
          throw new IllegalArgumentException(
            'HierarchicalRecordCreator: Both grandchildMatchField and grandchildParentMatchField must be provided together for field-based matching.'
          );
        }
        validateParentMatchFieldValues(
          req.childRecords,
          req.grandchildParentMatchField,
          'grandchildParentMatchField'
        );
        Set<String> childKeys = collectMatchKeys(
          req.childRecords,
          req.grandchildParentMatchField
        );
        validateChildMatchFieldValues(
          req.grandchildRecords,
          req.grandchildMatchField,
          'grandchildMatchField',
          childKeys
        );
      } else {
        // Index mode — existing validation
        if (req.grandchildRecords.size() != req.grandchildParentIndex.size()) {
          throw new IllegalArgumentException(
            'HierarchicalRecordCreator: grandchildRecords (' +
              req.grandchildRecords.size() +
              ') and grandchildParentIndex (' +
              req.grandchildParentIndex.size() +
              ') must be the same size.'
          );
        }
        validateIndexBounds(
          req.grandchildParentIndex,
          req.childRecords.size(),
          'grandchildParentIndex',
          'childRecords'
        );
      }
    }
  }

  /**
   * Checks that all index values are within bounds [0, maxSize).
   */
  private static void validateIndexBounds(
    List<Integer> indices,
    Integer maxSize,
    String indexName,
    String parentName
  ) {
    for (Integer i = 0; i < indices.size(); i++) {
      Integer idx = indices[i];
      if (idx == null || idx < 0 || idx >= maxSize) {
        throw new IllegalArgumentException(
          'HierarchicalRecordCreator: ' +
            indexName +
            '[' +
            i +
            '] = ' +
            idx +
            ' is out of bounds. Must be between 0 and ' +
            (maxSize - 1) +
            ' (size of ' +
            parentName +
            ').'
        );
      }
    }
  }

  /**
   * Populates the lookup field on each child record with the Id of its
   * designated parent record, based on the parallel index list.
   *
   * Uses SObject.put(fieldName, value) for generic field assignment —
   * works with any standard or custom lookup field on any object.
   */
  private static void wireChildLookups(
    List<SObject> children,
    String lookupFieldName,
    List<Integer> parentIndexes,
    List<SObject> parents
  ) {
    for (Integer i = 0; i < children.size(); i++) {
      Id parentId = parents[parentIndexes[i]].Id;
      children[i].put(lookupFieldName, parentId);
    }
  }

  /**
   * Populates the lookup field on each child record by matching field values
   * between child and parent records (case-insensitive).
   */
  private static void wireChildLookupsByMatchField(
    List<SObject> children,
    String lookupFieldName,
    String childMatchFieldName,
    String parentMatchFieldName,
    List<SObject> parents
  ) {
    // Build map: lowercase match value → parent SObject
    Map<String, SObject> parentByKey = new Map<String, SObject>();
    for (SObject parent : parents) {
      String key = String.valueOf(parent.get(parentMatchFieldName))
        .toLowerCase();
      parentByKey.put(key, parent);
    }

    // Wire each child to its matched parent
    for (SObject child : children) {
      String childKey = String.valueOf(child.get(childMatchFieldName))
        .toLowerCase();
      SObject matchedParent = parentByKey.get(childKey);
      child.put(lookupFieldName, matchedParent.Id);
    }
  }

  /**
   * Returns true if the request uses field-based matching for the child level.
   */
  private static Boolean usesChildFieldMatch(Request req) {
    return !String.isBlank(req.childMatchField) ||
      !String.isBlank(req.parentMatchField);
  }

  /**
   * Returns true if the request uses field-based matching for the grandchild level.
   */
  private static Boolean usesGrandchildFieldMatch(Request req) {
    return !String.isBlank(req.grandchildMatchField) ||
      !String.isBlank(req.grandchildParentMatchField);
  }

  /**
   * Validates that all parent-side records have non-null, non-blank, unique
   * values in the specified match field.
   */
  private static void validateParentMatchFieldValues(
    List<SObject> records,
    String fieldName,
    String fieldLabel
  ) {
    Set<String> seen = new Set<String>();
    for (Integer i = 0; i < records.size(); i++) {
      Object val = records[i].get(fieldName);
      if (val == null || String.isBlank(String.valueOf(val))) {
        throw new IllegalArgumentException(
          'HierarchicalRecordCreator: ' +
            fieldLabel +
            ' value is null or blank on record at position ' +
            i +
            '. All parent-side match field values must be non-blank.'
        );
      }
      String key = String.valueOf(val).toLowerCase();
      if (seen.contains(key)) {
        throw new IllegalArgumentException(
          'HierarchicalRecordCreator: Duplicate ' +
            fieldLabel +
            ' value \'' +
            String.valueOf(val) +
            '\' found on record at position ' +
            i +
            '. Parent-side match field values must be unique.'
        );
      }
      seen.add(key);
    }
  }

  /**
   * Validates that all child-side records have non-null, non-blank values
   * in the specified match field, and that every value exists in the parent
   * match field values.
   */
  private static void validateChildMatchFieldValues(
    List<SObject> records,
    String fieldName,
    String fieldLabel,
    Set<String> validParentKeys
  ) {
    for (Integer i = 0; i < records.size(); i++) {
      Object val = records[i].get(fieldName);
      if (val == null || String.isBlank(String.valueOf(val))) {
        throw new IllegalArgumentException(
          'HierarchicalRecordCreator: ' +
            fieldLabel +
            ' value is null or blank on record at position ' +
            i +
            '. All child-side match field values must be non-blank.'
        );
      }
      String key = String.valueOf(val).toLowerCase();
      if (!validParentKeys.contains(key)) {
        throw new IllegalArgumentException(
          'HierarchicalRecordCreator: ' +
            fieldLabel +
            ' value \'' +
            String.valueOf(val) +
            '\' on record at position ' +
            i +
            ' does not match any parent-side match field value.'
        );
      }
    }
  }

  /**
   * Collects lowercase match field values from a list of records into a Set.
   */
  private static Set<String> collectMatchKeys(
    List<SObject> records,
    String fieldName
  ) {
    Set<String> keys = new Set<String>();
    for (SObject rec : records) {
      Object val = rec.get(fieldName);
      if (val != null) {
        keys.add(String.valueOf(val).toLowerCase());
      }
    }
    return keys;
  }

  /**
   * Null-safe check for whether a list has records.
   */
  private static Boolean hasRecords(List<SObject> records) {
    return records != null && !records.isEmpty();
  }
}
