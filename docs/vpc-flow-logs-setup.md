# VPC Flow Logs 설정 가이드

<!-- 
AI Context: This document describes the VPC Flow Logs configuration for buzzvil-eks-ops cluster subnets.
Key information:
- Target subnets: subnet-0fa4e14c6224e0ee2 (1a), subnet-0062b1e9b2ddb2430 (1c)
- Destination: S3 bucket (buzzvil-aws-log-ap-northeast-1)
- Format: Parquet with Hive-compatible partitions
- Aggregation: 1-hour intervals
-->

## 개요

buzzvil-eks-ops 클러스터의 특정 서브넷에 대한 VPC Flow Logs를 S3에 Parquet 형식으로 저장하는 설정입니다.

## 최신 업데이트 (2025-12-10)

### Loki v3 Zone-Aware 라우팅 분석 지원

VPC Flow Logs를 통해 Loki v3의 `trafficDistribution: PreferClose` 설정 효과를 측정할 수 있습니다.

#### 포트 기반 트래픽 구분

**Loki v3 전용 포트 (Cross-AZ 분석용):**
```python
loki_v3_ports = {
    'gateway': [4080],
    'cache': [4090, 4091],
    'http': list(range(4101, 4108)),  # 4101-4107
    'grpc': list(range(4201, 4208))   # 4201-4207
}
```

**기존 Loki 포트 (비교 분석용):**
```python
existing_loki_ports = [3100, 8080, 9095, 11211]
```

#### Zone 매핑 (buzzvil-eks-ops)

```python
def get_zone_ops(ip):
    """buzzvil-eks-ops 클러스터 Zone 매핑"""
    parts = ip.split('.')
    if parts[0] == '10' and parts[1] == '0':
        third_octet = int(parts[2])
        # Zone A: 10.0.128.0/22 (10.0.128.0 - 10.0.131.255)
        if 128 <= third_octet <= 131:
            return 'ap-northeast-1a'
        # Zone C: 10.0.132.0/22 (10.0.132.0 - 10.0.135.255)
        elif 132 <= third_octet <= 135:
            return 'ap-northeast-1c'
    return 'unknown'
```

## 설정 정보

### 대상 서브넷

| Subnet ID | CIDR | Availability Zone | Flow Log ID |
|-----------|------|-------------------|-------------|
| subnet-0fa4e14c6224e0ee2 | 10.0.136.0/28 | ap-northeast-1a | fl-043fdbd04ce27629a |
| subnet-0062b1e9b2ddb2430 | 10.0.136.16/28 | ap-northeast-1c | fl-0c85eb0f571261fac |

### 저장 위치

- **S3 Bucket**: `buzzvil-aws-log-ap-northeast-1`
- **ARN**: `arn:aws:s3:::buzzvil-aws-log-ap-northeast-1`
- **Region**: ap-northeast-1
- **Account ID**: 591756927972

### 로그 형식

- **파일 형식**: Parquet
- **Hive 호환 파티션**: 활성화
- **시간별 파티션**: 1시간마다
- **집계 간격**: 60초 (1분)
- **트래픽 타입**: ALL (Accept + Reject)

### S3 경로 구조

```
s3://buzzvil-aws-log-ap-northeast-1/
└── AWSLogs/
    └── 591756927972/
        └── vpcflowlogs/
            └── region=ap-northeast-1/
                └── year=2025/
                    └── month=12/
                        └── day=09/
                            └── hour=10/
                                └── fl-043fdbd04ce27629a_vpcflowlogs_ap-northeast-1_20251209T1000Z_hash.parquet
```

## VPC Flow Logs 활성화 방법

### 1. AWS CLI를 통한 활성화

```bash
# AWS SSO 로그인
aws sso login --profile sso-adfit-devops

# VPC Flow Logs 생성 (서브넷별)
aws ec2 create-flow-logs \
  --resource-type Subnet \
  --resource-ids subnet-0fa4e14c6224e0ee2 subnet-0062b1e9b2ddb2430 \
  --traffic-type ALL \
  --log-destination-type s3 \
  --log-destination "arn:aws:s3:::buzzvil-aws-log-ap-northeast-1" \
  --log-format '${version} ${account-id} ${interface-id} ${srcaddr} ${dstaddr} ${srcport} ${dstport} ${protocol} ${packets} ${bytes} ${windowstart} ${windowend} ${action} ${flowlogstatus}' \
  --max-aggregation-interval 60 \
  --profile sso-adfit-devops
```

### 2. 상태 확인

```bash
# Flow Logs 상태 확인
aws ec2 describe-flow-logs \
  --filter "Name=resource-id,Values=subnet-0fa4e14c6224e0ee2,subnet-0062b1e9b2ddb2430" \
  --profile sso-adfit-devops

# S3에서 데이터 확인 (5-10분 후)
aws s3 ls s3://buzzvil-aws-log-ap-northeast-1/AWSLogs/591756927972/vpcflowlogs/ --recursive --profile sso-adfit-devops
```

## Cross-AZ 트래픽 분석

### trafficDistribution 효과 측정

```python
import pandas as pd
import boto3
from datetime import datetime, timedelta

class LokiTrafficAnalyzer:
    def __init__(self):
        # Loki v3 포트 정의
        self.loki_v3_ports = [4080, 4090, 4091] + list(range(4101, 4108)) + list(range(4201, 4208))
        self.existing_loki_ports = [3100, 8080, 9095, 11211]
        
    def get_zone_ops(self, ip):
        """buzzvil-eks-ops Zone 매핑"""
        parts = ip.split('.')
        if parts[0] == '10' and parts[1] == '0':
            third_octet = int(parts[2])
            if 128 <= third_octet <= 131:
                return 'ap-northeast-1a'
            elif 132 <= third_octet <= 135:
                return 'ap-northeast-1c'
        return 'unknown'
    
    def load_parquet_from_s3(self, bucket, prefix, start_date, end_date):
        """S3에서 Parquet 파일 로드"""
        import pyarrow.parquet as pq
        import pyarrow as pa
        
        s3 = boto3.client('s3')
        
        # 날짜 범위에 해당하는 파일 목록 가져오기
        dataframes = []
        
        current_date = start_date
        while current_date <= end_date:
            year = current_date.year
            month = current_date.month
            day = current_date.day
            
            # S3 경로 구성
            prefix_path = f"{prefix}region=ap-northeast-1/year={year}/month={month:02d}/day={day:02d}/"
            
            try:
                objects = s3.list_objects_v2(Bucket=bucket, Prefix=prefix_path)
                
                for obj in objects.get('Contents', []):
                    if obj['Key'].endswith('.parquet'):
                        # Parquet 파일 읽기
                        obj_key = obj['Key']
                        parquet_obj = s3.get_object(Bucket=bucket, Key=obj_key)
                        parquet_data = parquet_obj['Body'].read()
                        
                        # PyArrow로 파싱
                        table = pq.read_table(pa.BufferReader(parquet_data))
                        df = table.to_pandas()
                        
                        if not df.empty:
                            dataframes.append(df)
                            
            except Exception as e:
                print(f"Error processing date {current_date}: {e}")
                
            current_date += timedelta(days=1)
        
        return pd.concat(dataframes, ignore_index=True) if dataframes else pd.DataFrame()
    
    def analyze_cross_az_traffic(self, df):
        """Cross-AZ 트래픽 분석"""
        if df.empty:
            return {
                'total_traffic_gb': 0,
                'cross_az_traffic_gb': 0,
                'cross_az_percentage': 0,
                'cross_az_cost_usd': 0,
                'zone_distribution': {}
            }
        
        df['src_zone'] = df['srcaddr'].apply(self.get_zone_ops)
        df['dst_zone'] = df['dstaddr'].apply(self.get_zone_ops)
        
        # Cross-AZ 트래픽 필터링
        cross_az = df[
            (df['src_zone'] != df['dst_zone']) & 
            (df['src_zone'] != 'unknown') & 
            (df['dst_zone'] != 'unknown')
        ]
        
        # 통계 계산
        total_bytes = df['bytes'].sum()
        cross_az_bytes = cross_az['bytes'].sum()
        
        # Zone별 분포
        zone_dist = df.groupby(['src_zone', 'dst_zone'])['bytes'].sum().to_dict()
        
        return {
            'total_traffic_gb': total_bytes / (1024**3),
            'cross_az_traffic_gb': cross_az_bytes / (1024**3),
            'cross_az_percentage': (cross_az_bytes / total_bytes) * 100 if total_bytes > 0 else 0,
            'cross_az_cost_usd': (cross_az_bytes / (1024**3)) * 0.01,  # $0.01 per GB
            'zone_distribution': zone_dist
        }
    
    def compare_before_after_traffic_distribution(self):
        """trafficDistribution 적용 전후 비교"""
        bucket = 'buzzvil-aws-log-ap-northeast-1'
        prefix = 'AWSLogs/591756927972/vpcflowlogs/'
        
        # 적용 전 (2025-12-09)
        before_start = datetime(2025, 12, 9, 0, 0, 0)
        before_end = datetime(2025, 12, 9, 23, 59, 59)
        
        # 적용 후 (2025-12-10)
        after_start = datetime(2025, 12, 10, 12, 0, 0)  # 배포 완료 후
        after_end = datetime(2025, 12, 10, 23, 59, 59)
        
        print("Loading before data...")
        before_df = self.load_parquet_from_s3(bucket, prefix, before_start, before_end)
        
        print("Loading after data...")
        after_df = self.load_parquet_from_s3(bucket, prefix, after_start, after_end)
        
        # Loki v3 트래픽만 필터링
        before_loki_v3 = before_df[before_df['dstport'].isin(self.loki_v3_ports)]
        after_loki_v3 = after_df[after_df['dstport'].isin(self.loki_v3_ports)]
        
        # Cross-AZ 분석
        before_stats = self.analyze_cross_az_traffic(before_loki_v3)
        after_stats = self.analyze_cross_az_traffic(after_loki_v3)
        
        # 결과 출력
        print("\n=== trafficDistribution 효과 분석 ===")
        print(f"적용 전 (2025-12-09):")
        print(f"  Total traffic: {before_stats['total_traffic_gb']:.2f} GB")
        print(f"  Cross-AZ traffic: {before_stats['cross_az_traffic_gb']:.2f} GB")
        print(f"  Cross-AZ percentage: {before_stats['cross_az_percentage']:.2f}%")
        print(f"  Cross-AZ cost: ${before_stats['cross_az_cost_usd']:.2f}")
        
        print(f"\n적용 후 (2025-12-10):")
        print(f"  Total traffic: {after_stats['total_traffic_gb']:.2f} GB")
        print(f"  Cross-AZ traffic: {after_stats['cross_az_traffic_gb']:.2f} GB")
        print(f"  Cross-AZ percentage: {after_stats['cross_az_percentage']:.2f}%")
        print(f"  Cross-AZ cost: ${after_stats['cross_az_cost_usd']:.2f}")
        
        # 개선 효과 계산
        if before_stats['cross_az_percentage'] > 0:
            improvement = before_stats['cross_az_percentage'] - after_stats['cross_az_percentage']
            cost_savings = before_stats['cross_az_cost_usd'] - after_stats['cross_az_cost_usd']
            
            print(f"\n=== 개선 효과 ===")
            print(f"Cross-AZ 트래픽 감소: {improvement:.2f}%p")
            print(f"비용 절약: ${cost_savings:.2f}")
            if before_stats['cross_az_percentage'] > 0:
                print(f"절약률: {(improvement / before_stats['cross_az_percentage']) * 100:.1f}%")
        
        return before_stats, after_stats

# 사용 예시
def main():
    analyzer = LokiTrafficAnalyzer()
    before_stats, after_stats = analyzer.compare_before_after_traffic_distribution()

if __name__ == "__main__":
    main()
```

## 실시간 모니터링

### kubectl debug를 이용한 트래픽 모니터링

```bash
# Loki v3 distributor Pod에 debug 컨테이너 연결
kubectl --context buzzvil-eks-ops -n loki-v3 debug -it loki-v3-distributor-0 \
  --image=nicolaka/netshoot --target=distributor

# 디버그 컨테이너 내부에서 실행
timeout 300 tcpdump -i any -n port 4101 and 'tcp[tcpflags] & (tcp-syn) != 0' 2>/dev/null | \
  awk '{print $3}' | cut -d'.' -f1-4 | tee /tmp/source_ips.log

# Zone별 연결 수 분석 (buzzvil-eks-ops)
echo "=== Zone Analysis ==="
zone_a_count=$(grep -E '^10\.0\.(12[89]|13[01])\.' /tmp/source_ips.log | wc -l)
zone_c_count=$(grep -E '^10\.0\.(13[2-5])\.' /tmp/source_ips.log | wc -l)
total_count=$(wc -l < /tmp/source_ips.log)

echo "Zone A (ap-northeast-1a): $zone_a_count connections ($(( zone_a_count * 100 / total_count ))%)"
echo "Zone C (ap-northeast-1c): $zone_c_count connections ($(( zone_c_count * 100 / total_count ))%)"

# trafficDistribution 효과 확인
if [ $zone_a_count -gt $zone_c_count ]; then
    echo "✅ Same-zone routing working (more Zone A traffic)"
else
    echo "⚠️  Cross-zone traffic detected"
fi
```

## 비용 분석

### Cross-AZ 데이터 전송 비용

```python
# AWS Cross-AZ 데이터 전송 비용: $0.01 per GB
def calculate_monthly_savings(daily_cross_az_gb_before, daily_cross_az_gb_after):
    cost_per_gb = 0.01
    
    # 월간 비용 계산
    monthly_before = daily_cross_az_gb_before * 30 * cost_per_gb
    monthly_after = daily_cross_az_gb_after * 30 * cost_per_gb
    
    savings = monthly_before - monthly_after
    savings_percentage = (savings / monthly_before) * 100 if monthly_before > 0 else 0
    
    print(f"=== 월간 Cross-AZ 비용 분석 ===")
    print(f"적용 전: {daily_cross_az_gb_before:.2f} GB/day → ${monthly_before:.2f}/month")
    print(f"적용 후: {daily_cross_az_gb_after:.2f} GB/day → ${monthly_after:.2f}/month")
    print(f"월간 절약: ${savings:.2f} ({savings_percentage:.1f}%)")
    
    return savings

# 예상 절약 효과 (예시)
calculate_monthly_savings(
    daily_cross_az_gb_before=15.0,  # 적용 전
    daily_cross_az_gb_after=4.5     # 적용 후 (70% 감소)
)
```

## 데이터 쿼리 예시

### Athena를 이용한 분석

```sql
-- Loki v3 Cross-AZ 트래픽 분석 쿼리
CREATE EXTERNAL TABLE IF NOT EXISTS vpc_flow_logs (
  version int,
  account_id string,
  interface_id string,
  srcaddr string,
  dstaddr string,
  srcport int,
  dstport int,
  protocol int,
  packets bigint,
  bytes bigint,
  windowstart bigint,
  windowend bigint,
  action string,
  flowlogstatus string
)
PARTITIONED BY (
  region string,
  year string,
  month string,
  day string,
  hour string
)
STORED AS PARQUET
LOCATION 's3://buzzvil-aws-log-ap-northeast-1/AWSLogs/591756927972/vpcflowlogs/'
TBLPROPERTIES ('has_encrypted_data'='false');

-- 파티션 로드
MSCK REPAIR TABLE vpc_flow_logs;

-- Loki v3 Cross-AZ 트래픽 분석
WITH loki_v3_traffic AS (
  SELECT 
    srcaddr,
    dstaddr,
    dstport,
    bytes,
    CASE 
      WHEN split_part(srcaddr, '.', 3) BETWEEN '128' AND '131' THEN 'ap-northeast-1a'
      WHEN split_part(srcaddr, '.', 3) BETWEEN '132' AND '135' THEN 'ap-northeast-1c'
      ELSE 'unknown'
    END as src_zone,
    CASE 
      WHEN split_part(dstaddr, '.', 3) BETWEEN '128' AND '131' THEN 'ap-northeast-1a'
      WHEN split_part(dstaddr, '.', 3) BETWEEN '132' AND '135' THEN 'ap-northeast-1c'
      ELSE 'unknown'
    END as dst_zone
  FROM vpc_flow_logs
  WHERE year = '2025' 
    AND month = '12' 
    AND day = '10'
    AND dstport IN (4080, 4090, 4091, 4101, 4102, 4103, 4104, 4105, 4106, 4107, 4201, 4202, 4203, 4204, 4205, 4206, 4207)
)
SELECT 
  src_zone,
  dst_zone,
  COUNT(*) as connection_count,
  SUM(bytes) as total_bytes,
  SUM(bytes) / 1024.0 / 1024.0 / 1024.0 as total_gb,
  CASE WHEN src_zone != dst_zone THEN 'Cross-AZ' ELSE 'Same-AZ' END as traffic_type
FROM loki_v3_traffic
WHERE src_zone != 'unknown' AND dst_zone != 'unknown'
GROUP BY src_zone, dst_zone
ORDER BY total_bytes DESC;
```

## 문제 해결

### 1. Parquet 파일이 생성되지 않는 경우

```bash
# Flow Logs 상태 확인
aws ec2 describe-flow-logs \
  --filter "Name=resource-id,Values=subnet-0fa4e14c6224e0ee2,subnet-0062b1e9b2ddb2430" \
  --profile sso-adfit-devops

# S3 버킷 권한 확인
aws s3api get-bucket-policy --bucket buzzvil-aws-log-ap-northeast-1 --profile sso-adfit-devops
```

### 2. trafficDistribution이 효과가 없는 경우

```bash
# Kubernetes 버전 확인 (1.30+ 필요)
kubectl --context buzzvil-eks-ops version --short

# 서비스 설정 확인
kubectl --context buzzvil-eks-ops -n loki-v3 get services -o yaml | grep -A 1 "trafficDistribution"

# Pod 분포 확인
kubectl --context buzzvil-eks-ops -n loki-v3 get pods -o wide | grep -E "(distributor|ingester|querier)"
```

### 3. 데이터 분석 오류

```python
# PyArrow 설치 필요
pip install pyarrow pandas boto3

# S3 접근 권한 확인
import boto3
s3 = boto3.client('s3')
s3.list_objects_v2(Bucket='buzzvil-aws-log-ap-northeast-1', Prefix='AWSLogs/', MaxKeys=1)
```

## 참고 자료

- [AWS VPC Flow Logs 사용 설명서](https://docs.aws.amazon.com/vpc/latest/userguide/flow-logs.html)
- [Parquet 형식 Flow Logs](https://docs.aws.amazon.com/vpc/latest/userguide/flow-logs-s3.html#flow-logs-s3-path-format)
- [Cross-AZ 데이터 전송 요금](https://aws.amazon.com/ec2/pricing/on-demand/)
- [Kubernetes trafficDistribution](https://kubernetes.io/docs/concepts/services-networking/service/#traffic-distribution)
- [Loki v3 Troubleshooting Guide](loki-v3-troubleshooting-guide.md)