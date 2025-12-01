# Implementation Plan

- [x] 1. Terraform으로 S3 버킷 및 IAM Role 프로비저닝
  - terraform-resources 리포지토리에 Loki용 S3 버킷 리소스 정의
  - IAM Role 및 정책 생성 (S3 읽기/쓰기 권한)
  - Output으로 버킷 이름과 Role ARN 출력
  - _Requirements: 1.1, 1.2, 1.3, 1.4_

- [x] 1.1 Terraform 설정 검증 테스트 작성
  - S3 버킷 생성 확인
  - IAM Role 및 정책 생성 확인
  - Output 값 검증
  - **Property 1: IAM 정책 권한 완전성**
  - **Validates: Requirements 1.3**
  - _Requirements: 1.1, 1.2, 1.3, 1.4_

- [x] 2. buzz-k8s-resources에 Loki Helm 차트 설정
  - Loki Helm 차트 디렉토리 구조 생성
  - values.yaml 작성 (멀티테넌시 활성화, S3 백엔드 설정)
  - 테넌트별 로그 격리 정책 정의 (ops, dev, prod)
  - ServiceAccount에 IAM Role ARN 어노테이션 추가
  - _Requirements: 2.1, 2.2, 2.3, 2.4_

- [x] 2.1 Helm 차트 설정 검증 테스트 작성
  - Chart.yaml 및 values.yaml 파일 존재 확인
  - 멀티테넌시 설정 (auth_enabled: true) 확인
  - S3 백엔드 설정 검증
  - _Requirements: 2.1, 2.2, 2.3, 2.4_

- [ ] 3. Gitploy로 Loki를 ops 클러스터에 배포
  - Gitploy를 통해 ops 클러스터로 배포 트리거
  - kubectl로 Loki Pod 상태 확인
  - Loki 서비스 엔드포인트 접근성 확인
  - Health check 엔드포인트 검증
  - _Requirements: 3.1, 3.2, 3.3, 3.4_

- [ ] 3.1 Loki 배포 검증 테스트 작성
  - Pod Running 상태 확인
  - 서비스 엔드포인트 응답 확인
  - Health check 200 OK 응답 확인
  - _Requirements: 3.1, 3.2, 3.3, 3.4_

- [ ] 4. buzz-k8s-resources에 Alloy Helm 차트 설정
  - Alloy Helm 차트 디렉토리 구조 생성
  - values.yaml 작성 (Loki 엔드포인트 설정)
  - 로그 수집 규칙 정의 (discovery.kubernetes, loki.source.kubernetes)
  - 환경별 values 파일 생성 (values-ops.yaml, values-dev.yaml, values-prod.yaml)
  - 각 환경의 tenant_id 설정 (ops, dev, prod)
  - _Requirements: 5.1, 5.2, 5.3, 5.4_

- [ ] 4.1 Alloy Helm 차트 설정 검증 테스트 작성
  - Chart.yaml 및 values.yaml 파일 존재 확인
  - Loki 엔드포인트 설정 확인
  - 환경별 values 파일 존재 및 tenant_id 확인
  - _Requirements: 5.1, 5.2, 5.3, 5.4_

- [ ] 5. Gitploy로 Alloy를 ops 클러스터에 배포
  - Gitploy를 통해 ops 클러스터로 배포 트리거 (values-ops.yaml 사용)
  - kubectl로 Alloy Pod 상태 확인
  - Alloy Pod 로그에서 로그 수집 활동 확인
  - _Requirements: 6.1, 6.2, 6.3_

- [ ] 5.1 Alloy 배포 및 수집 검증 테스트 작성
  - Pod Running 상태 확인
  - Alloy 로그에서 수집 메시지 확인
  - _Requirements: 6.1, 6.2, 6.3, 7.1, 7.2_

- [ ] 6. Alloy 로그 수집 상태 모니터링 구현
  - kubectl logs로 Alloy Pod 로그 조회 스크립트 작성
  - Alloy 메트릭 엔드포인트에서 수집 통계 조회
  - 수집 오류 로깅 확인
  - _Requirements: 7.1, 7.2, 7.3_

- [ ] 7. Loki 로그 쿼리 및 검증 구현
  - LogQL 쿼리 실행 스크립트 작성
  - 시간 범위 쿼리 구현
  - 테넌트별 로그 조회 구현
  - 오류 처리 및 메시지 출력
  - _Requirements: 8.1, 8.2, 8.3, 8.4_

- [ ] 7.1 Loki 쿼리 Property 테스트 작성
  - **Property 2: 시간 범위 쿼리 정확성**
  - **Validates: Requirements 8.2**
  - _Requirements: 8.2_

- [ ] 7.2 테넌트 격리 Property 테스트 작성
  - **Property 3: 테넌트 격리 보장**
  - **Validates: Requirements 8.3**
  - _Requirements: 8.3_

- [ ] 8. S3 로그 저장 확인 구현
  - AWS CLI로 S3 버킷 객체 목록 조회 스크립트 작성
  - 객체 메타데이터 (크기, 생성 시간) 조회
  - S3 객체 다운로드 및 읽기 권한 확인
  - 최신 로그 타임스탬프 확인 및 지연 감지
  - _Requirements: 9.1, 9.2, 9.3, 9.4_

- [ ] 8.1 로그 저장 지연 감지 Property 테스트 작성
  - **Property 4: 로그 저장 지연 감지**
  - **Validates: Requirements 9.4**
  - _Requirements: 9.4_

- [ ] 9. 로그 수집 누락 모니터링 시스템 구현
  - 예상 로그 라인 수 계산 함수 구현
  - Loki에서 실제 수집된 로그 라인 수 집계 함수 구현
  - 수집률 계산 함수 구현 (예상 대비 실제 비율)
  - 수집률 임계값 체크 및 알림 발송 함수 구현
  - 누락된 소스 식별 로직 구현
  - _Requirements: 10.1, 10.2, 10.3, 10.4_

- [ ] 9.1 로그 수집 완전성 Property 테스트 작성
  - **Property 5: 로그 수집 완전성 검증**
  - **Validates: Requirements 10.1, 10.2, 10.3, 10.4**
  - _Requirements: 10.1, 10.2, 10.3, 10.4_

- [ ] 10. Loki 비용 모니터링 시스템 구현
  - Loki 관련 리소스 비용 데이터 수집 함수 구현
  - 비용 집계 함수 구현
  - 비용 임계값 체크 및 알림 발송 함수 구현
  - 일별/주별/월별 비용 리포트 생성 함수 구현
  - _Requirements: 4.1, 4.2, 4.3_

- [ ] 10.1 Loki 비용 집계 Property 테스트 작성
  - **Property 6: Loki 비용 집계 정확성**
  - **Validates: Requirements 4.1**
  - _Requirements: 4.1_

- [ ] 10.2 Loki 비용 임계값 알림 Property 테스트 작성
  - **Property 7: Loki 비용 임계값 알림**
  - **Validates: Requirements 4.2**
  - _Requirements: 4.2_

- [ ] 10.3 Loki 비용 리포트 구조 Property 테스트 작성
  - **Property 8: Loki 비용 리포트 구조**
  - **Validates: Requirements 4.3**
  - _Requirements: 4.3_

- [ ] 11. Alloy 비용 모니터링 시스템 구현
  - Alloy 관련 리소스 비용 데이터 수집 함수 구현
  - 비용 집계 함수 구현
  - 비용 임계값 체크 및 알림 발송 함수 구현
  - 클러스터별 비용 분석 리포트 생성 함수 구현
  - _Requirements: 11.1, 11.2, 11.3_

- [ ] 11.1 Alloy 비용 집계 Property 테스트 작성
  - **Property 9: Alloy 비용 집계 정확성**
  - **Validates: Requirements 11.1**
  - _Requirements: 11.1_

- [ ] 11.2 Alloy 비용 임계값 알림 Property 테스트 작성
  - **Property 10: Alloy 비용 임계값 알림**
  - **Validates: Requirements 11.2**
  - _Requirements: 11.2_

- [ ] 11.3 Alloy 비용 클러스터별 분석 Property 테스트 작성
  - **Property 11: Alloy 비용 클러스터별 분석**
  - **Validates: Requirements 11.3**
  - _Requirements: 11.3_

- [ ] 12. Checkpoint - ops 클러스터 검증
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 13. Gitploy로 Alloy를 dev 클러스터에 배포
  - Gitploy를 통해 dev 클러스터로 배포 트리거 (values-dev.yaml 사용)
  - kubectl로 Alloy Pod 상태 확인
  - Alloy 로그 수집 상태 확인
  - Loki에서 dev 테넌트 로그 조회 확인
  - _Requirements: 12.1, 12.2, 12.3_

- [ ] 13.1 dev 클러스터 배포 검증 테스트 작성
  - Helm 차트 버전 일치 확인
  - dev values 파일 적용 확인
  - Pod 상태 및 로그 수집 확인
  - _Requirements: 12.1, 12.2, 12.3_

- [ ] 14. Gitploy로 Alloy를 prod 클러스터에 배포
  - Gitploy를 통해 prod 클러스터로 배포 트리거 (values-prod.yaml 사용)
  - kubectl로 Alloy Pod 상태 확인
  - Alloy 로그 수집 상태 확인
  - Loki에서 prod 테넌트 로그 조회 확인
  - _Requirements: 13.1, 13.2, 13.3_

- [ ] 14.1 prod 클러스터 배포 검증 테스트 작성
  - Helm 차트 버전 일치 확인
  - prod values 파일 적용 확인
  - Pod 상태 및 로그 수집 확인
  - _Requirements: 13.1, 13.2, 13.3_

- [ ] 15. 전체 클러스터 통합 검증
  - 모든 클러스터(ops, dev, prod)의 로그가 Loki에서 조회되는지 확인
  - 테넌트별 로그 격리 검증
  - S3에 모든 클러스터의 로그가 저장되는지 확인
  - _Requirements: 13.4_

- [ ] 15.1 전체 클러스터 통합 테스트 작성
  - 각 테넌트별 로그 조회 성공 확인
  - 테넌트 격리 검증
  - S3 저장 확인
  - _Requirements: 13.4_

- [ ] 16. Final Checkpoint - 전체 시스템 검증
  - Ensure all tests pass, ask the user if questions arise.
