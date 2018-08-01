output "addresses" {
  value = "${sort(google_compute_address.default.*.address)}"
}
