package com.lagou.repository;

import com.lagou.entity.BOrder;
import org.springframework.data.jpa.repository.JpaRepository;

public interface BOrderRepository extends JpaRepository<BOrder,Long> {
}
