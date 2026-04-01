# FaceAttend — Milestone 5 Testing Report

**Project:** FaceAttend — AI Mobile Attendance Management
**Date:** April 1, 2026
**Tester:** Subrahmanya Hegde

---

## 1. Unit Tests — Auth Routes (Jest)

Tool: Jest + Supertest
File: backend/src/routes/auth.test.js

| Test | Expected | Result |
|------|----------|--------|
| Register new user | 200 + token returned | PASS |
| Register duplicate email | 400 error | PASS |
| Register missing fields | 400/500 error | PASS |
| Login with correct password | 200 + token returned | PASS |
| Login with wrong password | 401 Unauthorized | PASS |
| Login with unknown email | 401 Unauthorized | PASS |

**Total: 6/6 passed — 100% pass rate**

---

## 2. Accuracy Test — Same Face 20 Runs (Real DeepFace)

Model: FaceNet512 via DeepFace
Tool: POST /api/face/verify with same base64 image 20 times

| Metric | Value |
|--------|-------|
| Total runs | 20 |
| Correct matches | 20 |
| Accuracy | 100% |
| Similarity score | 1.0 (exact match) |

**Result: 20/20 = 100% accuracy**

---

## 3. False Positive Test — Different Face

| Test | Expected | Actual Similarity | Result |
|------|----------|------------------|--------|
| Different face verify | success: false | 0.261 | PASS |

Threshold set to 0.70 — different face scored 0.261, well below threshold.

---

## 4. Timing Test

| Operation | Target | Actual | Result |
|-----------|--------|--------|--------|
| Face verify response | < 3 seconds | 0.045s | PASS |
| Face enroll response | < 60 seconds | ~1s | PASS |
| Auth register | < 1 second | 0.14s | PASS |
| Auth login | < 1 second | 0.11s | PASS |

---

## 5. Integration Tests — Face Enroll and Verify

| Test | Expected | Result |
|------|----------|--------|
| Enroll face via API | success:true, dims:512 | PASS |
| Verify same face | similarity:1.0, success:true | PASS |
| Verify different face | similarity:0.26, success:false | PASS |
| Embedding stored in pgvector | vector_dims=512 | PASS |
| Attendance mark after enroll | marked:true | PASS |

**Total: 5/5 passed — 100% pass rate**

---

## 6. Attendance Module Tests (Milestone 4)

| Test | Expected | Result |
|------|----------|--------|
| Teacher opens session | session created | PASS |
| Student marks attendance | marked:true | PASS |
| Duplicate mark blocked | error returned | PASS |
| Student history returned | attendancePct shown | PASS |
| Class report returned | sessions + records | PASS |
| Manual override | status updated | PASS |
| Student blocked from opening session | 403 error | PASS |
| Mark after session closed | error returned | PASS |

**Total: 8/8 passed — 100% pass rate**

---

## 7. Usability Notes

- Average verify time: 0.045 seconds (target < 3s) — PASS
- Average enroll time: ~1 second (target < 60s) — PASS
- API responses are clear and consistent JSON
- Error messages are descriptive and actionable
- DeepFace FaceNet512 model produces reliable 512-dim embeddings

---

## 8. DeepFace Configuration

- Model: FaceNet512
- Threshold: 0.70 (cosine similarity)
- Same face similarity: 1.0
- Different face similarity: 0.26
- Gap between same/different: 0.74 (strong separation)

---

## Summary

| Category | Tests | Passed | Pass Rate |
|----------|-------|--------|-----------|
| Auth unit tests | 6 | 6 | 100% |
| Face pipeline | 5 | 5 | 100% |
| Attendance module | 8 | 8 | 100% |
| Timing tests | 4 | 4 | 100% |
| **Total** | **23** | **23** | **100%** |

