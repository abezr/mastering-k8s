package v1alpha1

import (
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// +kubebuilder:object:root=true
// +kubebuilder:subresource:status
// +kubebuilder:printcolumn:name="Ready",type="boolean",JSONPath=".status.ready",description="Whether the resource is ready"
type NewResource struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	Spec   NewResourceSpec   `json:"spec,omitempty"`
	Status NewResourceStatus `json:"status,omitempty"`
}

type NewResourceSpec struct {
	Foo string `json:"foo,omitempty"`
	// Adding this field to help with testing reconciliation
	ReconcileTrigger bool `json:"reconcileTrigger,omitempty"`
}

type NewResourceStatus struct {
	// Ready indicates whether the resource is ready
	// Defaulting to false to ensure status is always visible
	// +kubebuilder:default=false
	Ready bool `json:"ready"`
}

// +kubebuilder:object:root=true
type NewResourceList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`
	Items           []NewResource `json:"items"`
}